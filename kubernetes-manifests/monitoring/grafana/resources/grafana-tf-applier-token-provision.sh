#!/bin/bash
#
# Runs alongside the grafana container as a sidecar. Ensures a
# "terraform-applier" service account + API token exists and publishes the
# token as the terraform-applier-grafana-token secret, which the
# terraform-applier dashboards Module reads to manage dashboards.

set -o nounset
set -o pipefail

readonly GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
readonly GRAFANA_SERVICE_ACCOUNT_NAME='terraform-applier'
readonly GRAFANA_SERVICE_ACCOUNT_ROLE='Admin'
readonly GRAFANA_TOKEN_NAME='terraform-applier-token'

readonly K8S_SA_DIR='/var/run/secrets/grafana-sidecar-sa'
readonly K8S_SECRET_NAME='terraform-applier-grafana-token'

readonly HEALTH_POLL_INTERVAL_SECONDS=2
readonly HEALTH_POLL_TIMEOUT_SECONDS=300
readonly RETRY_BACKOFF_SECONDS=10
readonly IDLE_SLEEP_SECONDS=3600

#######################################
# Prints an informational message to STDOUT.
# Arguments:
#   message
#######################################
log() {
  printf '%s\n' "$1"
}

#######################################
# Prints an error message to STDERR.
# Arguments:
#   message
#######################################
err() {
  printf '%s\n' "$1" >&2
}

#######################################
# Performs an HTTP request, writing the response body to a file.
# Arguments:
#   method       - HTTP method (GET, POST, PATCH, DELETE)
#   url          - target URL
#   out_file     - path to write the response body to
#   auth_header  - full "Authorization: ..." header value, or '' for none
#   ca_cert      - path to a CA bundle for TLS verification, or '' for none
#   data         - request body to send, or '' for none
#   content_type - request Content-Type, defaults to application/json
# Outputs:
#   STDOUT: the HTTP status code
#######################################
http_request() {
  local method="$1"
  local url="$2"
  local out_file="$3"
  local auth_header="$4"
  local ca_cert="$5"
  local data="$6"
  local content_type="${7:-application/json}"

  local -a curl_args=(
    --silent
    --show-error
    --request "${method}"
    --output "${out_file}"
    --write-out '%{http_code}'
  )

  if [[ -n "${auth_header}" ]]; then
    curl_args+=(--header "${auth_header}")
  fi
  if [[ -n "${ca_cert}" ]]; then
    curl_args+=(--cacert "${ca_cert}")
  fi
  if [[ -n "${data}" ]]; then
    curl_args+=(--header "Content-Type: ${content_type}" --data "${data}")
  fi

  curl "${curl_args[@]}" "${url}"
}

#######################################
# Calls the Grafana HTTP API.
# Arguments:
#   method, path, out_file, auth_header, data (optional)
# Outputs:
#   STDOUT: the HTTP status code
#######################################
grafana_request() {
  local method="$1"
  local path="$2"
  local out_file="$3"
  local auth_header="$4"
  local data="${5:-}"

  http_request "${method}" "${GRAFANA_URL}${path}" "${out_file}" \
    "${auth_header}" '' "${data}"
}

#######################################
# Builds the HTTP Basic auth header for the bootstrap admin account.
# Globals:
#   GF_SECURITY_ADMIN_USER, GF_SECURITY_ADMIN_PASSWORD
# Outputs:
#   STDOUT: the Authorization header value
#######################################
grafana_auth_header() {
  local credentials
  credentials="$(printf '%s:%s' "${GF_SECURITY_ADMIN_USER}" \
    "${GF_SECURITY_ADMIN_PASSWORD}" | base64 | tr -d '\n')"
  printf 'Authorization: Basic %s' "${credentials}"
}

#######################################
# Blocks until Grafana's health endpoint responds, or times out.
# Returns:
#   1 if grafana never became healthy in HEALTH_POLL_TIMEOUT_SECONDS
#######################################
wait_for_grafana() {
  local body_file
  body_file="$(mktemp)"
  local now
  now="$(date +%s)"
  local deadline=$((now + HEALTH_POLL_TIMEOUT_SECONDS))

  log 'waiting for grafana...'
  while ((now < deadline)); do
    local status
    status="$(http_request GET "${GRAFANA_URL}/api/health" "${body_file}" \
      '' '' '' 2>/dev/null)"
    if [[ "${status}" == '200' ]]; then
      log 'grafana is up'
      rm -f "${body_file}"
      return 0
    fi
    sleep "${HEALTH_POLL_INTERVAL_SECONDS}"
    now="$(date +%s)"
  done

  rm -f "${body_file}"
  err 'grafana did not become healthy in time'
  return 1
}

#######################################
# Finds the terraform-applier service account, creating it if missing.
# Arguments:
#   auth_header
# Outputs:
#   STDOUT: the service account id
# Returns:
#   1 on API failure
#######################################
get_or_create_service_account() {
  local auth_header="$1"
  local body_file
  body_file="$(mktemp)"

  local status
  status="$(grafana_request GET \
    "/api/serviceaccounts/search?query=${GRAFANA_SERVICE_ACCOUNT_NAME}" \
    "${body_file}" "${auth_header}")"
  if [[ "${status}" != '200' ]]; then
    err "service account search failed: ${status} $(cat "${body_file}")"
    rm -f "${body_file}"
    return 1
  fi

  local account_id
  account_id="$(jq -r --arg name "${GRAFANA_SERVICE_ACCOUNT_NAME}" \
    '.serviceAccounts[] | select(.name == $name) | .id' "${body_file}")"
  if [[ -n "${account_id}" ]]; then
    rm -f "${body_file}"
    printf '%s' "${account_id}"
    return 0
  fi

  local create_payload
  create_payload="$(jq -n --arg name "${GRAFANA_SERVICE_ACCOUNT_NAME}" \
    --arg role "${GRAFANA_SERVICE_ACCOUNT_ROLE}" \
    '{name: $name, role: $role}')"

  status="$(grafana_request POST '/api/serviceaccounts' "${body_file}" \
    "${auth_header}" "${create_payload}")"
  if [[ "${status}" != '200' && "${status}" != '201' ]]; then
    err "service account create failed: ${status} $(cat "${body_file}")"
    rm -f "${body_file}"
    return 1
  fi

  account_id="$(jq -r '.id' "${body_file}")"
  rm -f "${body_file}"
  printf '%s' "${account_id}"
}

#######################################
# Deletes any existing tokens on the service account and mints a fresh
# one. Grafana never returns a token's value after creation, so the
# existing set is always rotated clean rather than reused.
# Arguments:
#   auth_header, account_id
# Outputs:
#   STDOUT: the new token value
# Returns:
#   1 on API failure
#######################################
rotate_token() {
  local auth_header="$1"
  local account_id="$2"
  local body_file
  body_file="$(mktemp)"

  local status
  status="$(grafana_request GET \
    "/api/serviceaccounts/${account_id}/tokens" "${body_file}" \
    "${auth_header}")"
  if [[ "${status}" != '200' ]]; then
    err "token list failed: ${status} $(cat "${body_file}")"
    rm -f "${body_file}"
    return 1
  fi

  local token_id
  while IFS= read -r token_id; do
    local delete_body_file
    delete_body_file="$(mktemp)"
    status="$(grafana_request DELETE \
      "/api/serviceaccounts/${account_id}/tokens/${token_id}" \
      "${delete_body_file}" "${auth_header}")"
    if [[ "${status}" != '200' ]]; then
      err "token delete failed: ${status} $(cat "${delete_body_file}")"
      rm -f "${body_file}" "${delete_body_file}"
      return 1
    fi
    rm -f "${delete_body_file}"
  done < <(jq -r '.[].id' "${body_file}")

  local create_payload
  create_payload="$(jq -n --arg name "${GRAFANA_TOKEN_NAME}" '{name: $name}')"

  status="$(grafana_request POST "/api/serviceaccounts/${account_id}/tokens" \
    "${body_file}" "${auth_header}" "${create_payload}")"
  if [[ "${status}" != '200' && "${status}" != '201' ]]; then
    err "token create failed: ${status} $(cat "${body_file}")"
    rm -f "${body_file}"
    return 1
  fi

  jq -r '.key' "${body_file}"
  rm -f "${body_file}"
}

#######################################
# Creates or updates the terraform-applier-grafana-token secret via the
# Kubernetes API.
# Arguments:
#   token_value, api_server, auth_header, ca_cert, namespace
# Returns:
#   1 on API failure
#######################################
publish_secret() {
  local token_value="$1"
  local api_server="$2"
  local auth_header="$3"
  local ca_cert="$4"
  local namespace="$5"

  local encoded_token
  encoded_token="$(printf '%s' "${token_value}" | base64 | tr -d '\n')"

  local secret_payload
  secret_payload="$(jq -n --arg name "${K8S_SECRET_NAME}" \
    --arg token "${encoded_token}" \
    '{apiVersion: "v1", kind: "Secret", metadata: {name: $name},
        type: "Opaque", data: {token: $token}}')"

  local secrets_url="${api_server}/api/v1/namespaces/${namespace}/secrets"
  local body_file
  body_file="$(mktemp)"

  local status
  status="$(http_request POST "${secrets_url}" "${body_file}" \
    "${auth_header}" "${ca_cert}" "${secret_payload}")"
  if [[ "${status}" == '200' || "${status}" == '201' ]]; then
    log "created secret ${K8S_SECRET_NAME}"
    rm -f "${body_file}"
    return 0
  fi

  if [[ "${status}" == '409' ]]; then
    local patch_payload
    patch_payload="$(jq -n --arg token "${encoded_token}" \
      '{data: {token: $token}}')"
    status="$(http_request PATCH "${secrets_url}/${K8S_SECRET_NAME}" \
      "${body_file}" "${auth_header}" "${ca_cert}" "${patch_payload}" \
      'application/merge-patch+json')"
    if [[ "${status}" == '200' ]]; then
      log "updated secret ${K8S_SECRET_NAME}"
      rm -f "${body_file}"
      return 0
    fi
  fi

  err "secret upsert failed: ${status} $(cat "${body_file}")"
  rm -f "${body_file}"
  return 1
}

#######################################
# Runs one full provisioning pass: waits for grafana, rotates the
# service account token, and publishes it as a k8s secret.
# Returns:
#   1 if any step failed
#######################################
provision_once() {
  wait_for_grafana || return 1

  local auth_header
  auth_header="$(grafana_auth_header)"

  local account_id
  account_id="$(get_or_create_service_account "${auth_header}")" || return 1

  local token_value
  token_value="$(rotate_token "${auth_header}" "${account_id}")" || return 1

  local k8s_token k8s_namespace
  k8s_token="$(cat "${K8S_SA_DIR}/token")"
  k8s_namespace="$(cat "${K8S_SA_DIR}/namespace")"
  local api_server
  api_server="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"

  publish_secret "${token_value}" "${api_server}" \
    "Authorization: Bearer ${k8s_token}" "${K8S_SA_DIR}/ca.crt" \
    "${k8s_namespace}" || return 1
}

#######################################
# Provisions once (retrying with backoff on failure), then idles: a pod
# restart is what triggers the next rotation.
#######################################
main() {
  while ! provision_once; do
    err "provisioning failed, retrying in ${RETRY_BACKOFF_SECONDS}s"
    sleep "${RETRY_BACKOFF_SECONDS}"
  done

  while true; do
    sleep "${IDLE_SLEEP_SECONDS}"
  done
}

main "$@"
