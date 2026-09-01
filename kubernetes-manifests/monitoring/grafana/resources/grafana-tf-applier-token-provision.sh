#!/bin/bash
#
# Runs alongside the grafana container as a sidecar. Ensures a set of
# Grafana service accounts + API tokens exist and publishes each token as
# a kubernetes secret for the corresponding consumer to use:
#
#   - terraform-applier (Admin): manages dashboards via terraform-applier
#   - mcp-grafana (Viewer): read-only access for the mcp-grafana server

set -o nounset
set -o pipefail

readonly GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"

# One entry per service account to provision. Fields, separated by '|':
#   service account name | role | token name | k8s secret name
readonly SERVICE_ACCOUNTS=(
  'terraform-applier|Admin|terraform-applier-token|terraform-applier-grafana-token'
  'mcp-grafana|Viewer|mcp-grafana-token|mcp-grafana-grafana-token'
)

readonly K8S_SA_DIR='/var/run/secrets/grafana-sidecar-sa'

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
# Finds a service account by name, creating it if missing.
# Arguments:
#   auth_header, sa_name, sa_role
# Outputs:
#   STDOUT: the service account id
# Returns:
#   1 on API failure
#######################################
get_or_create_service_account() {
  local auth_header="$1"
  local sa_name="$2"
  local sa_role="$3"
  local body_file
  body_file="$(mktemp)"

  local status
  status="$(grafana_request GET \
    "/api/serviceaccounts/search?query=${sa_name}" \
    "${body_file}" "${auth_header}")"
  if [[ "${status}" != '200' ]]; then
    err "service account search failed: ${status} $(cat "${body_file}")"
    rm -f "${body_file}"
    return 1
  fi

  local account_id
  account_id="$(jq -r --arg name "${sa_name}" \
    '.serviceAccounts[] | select(.name == $name) | .id' "${body_file}")"
  if [[ -n "${account_id}" ]]; then
    rm -f "${body_file}"
    printf '%s' "${account_id}"
    return 0
  fi

  local create_payload
  create_payload="$(jq -n --arg name "${sa_name}" \
    --arg role "${sa_role}" \
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
#   auth_header, account_id, token_name
# Outputs:
#   STDOUT: the new token value
# Returns:
#   1 on API failure
#######################################
rotate_token() {
  local auth_header="$1"
  local account_id="$2"
  local token_name="$3"
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
  create_payload="$(jq -n --arg name "${token_name}" '{name: $name}')"

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
# Creates or updates a kubernetes secret with the given token via the
# Kubernetes API.
# Arguments:
#   token_value, secret_name, api_server, auth_header, ca_cert, namespace
# Returns:
#   1 on API failure
#######################################
publish_secret() {
  local token_value="$1"
  local secret_name="$2"
  local api_server="$3"
  local auth_header="$4"
  local ca_cert="$5"
  local namespace="$6"

  local encoded_token
  encoded_token="$(printf '%s' "${token_value}" | base64 | tr -d '\n')"

  local secret_payload
  secret_payload="$(jq -n --arg name "${secret_name}" \
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
    log "created secret ${secret_name}"
    rm -f "${body_file}"
    return 0
  fi

  if [[ "${status}" == '409' ]]; then
    local patch_payload
    patch_payload="$(jq -n --arg token "${encoded_token}" \
      '{data: {token: $token}}')"
    status="$(http_request PATCH "${secrets_url}/${secret_name}" \
      "${body_file}" "${auth_header}" "${ca_cert}" "${patch_payload}" \
      'application/merge-patch+json')"
    if [[ "${status}" == '200' ]]; then
      log "updated secret ${secret_name}"
      rm -f "${body_file}"
      return 0
    fi
  fi

  err "secret upsert failed: ${status} $(cat "${body_file}")"
  rm -f "${body_file}"
  return 1
}

#######################################
# Provisions a single service account: waits for grafana, ensures the
# account exists, rotates its token, and publishes it as a k8s secret.
# Arguments:
#   auth_header, api_server, ca_cert, namespace, sa_name, sa_role,
#   token_name, secret_name
# Returns:
#   1 if any step failed
#######################################
provision_service_account() {
  local auth_header="$1"
  local api_server="$2"
  local ca_cert="$3"
  local namespace="$4"
  local sa_name="$5"
  local sa_role="$6"
  local token_name="$7"
  local secret_name="$8"

  local account_id
  account_id="$(get_or_create_service_account "${auth_header}" \
    "${sa_name}" "${sa_role}")" || return 1

  local token_value
  token_value="$(rotate_token "${auth_header}" "${account_id}" \
    "${token_name}")" || return 1

  local k8s_token
  k8s_token="$(cat "${K8S_SA_DIR}/token")"

  publish_secret "${token_value}" "${secret_name}" "${api_server}" \
    "Authorization: Bearer ${k8s_token}" "${ca_cert}" \
    "${namespace}" || return 1
}

#######################################
# Runs one full provisioning pass: waits for grafana, then provisions
# every service account in SERVICE_ACCOUNTS.
# Returns:
#   1 if any step failed
#######################################
provision_once() {
  wait_for_grafana || return 1

  local auth_header
  auth_header="$(grafana_auth_header)"

  local k8s_namespace api_server
  k8s_namespace="$(cat "${K8S_SA_DIR}/namespace")"
  api_server="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"

  local entry sa_name sa_role token_name secret_name
  for entry in "${SERVICE_ACCOUNTS[@]}"; do
    IFS='|' read -r sa_name sa_role token_name secret_name <<< "${entry}"
    log "provisioning service account ${sa_name}"
    if ! provision_service_account "${auth_header}" "${api_server}" \
        "${K8S_SA_DIR}/ca.crt" "${k8s_namespace}" "${sa_name}" \
        "${sa_role}" "${token_name}" "${secret_name}"; then
      return 1
    fi
  done
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