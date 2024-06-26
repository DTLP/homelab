#!/usr/bin/env bash
# Original script from https://github.com/arturscheiner/kuberverse

SCALER_IP=$1
MASTER_IPS=$(echo $2 | sed -e 's/,//g' -e 's/\]//g' -e 's/\[//g')

export DEBIAN_FRONTEND=noninteractive

echo -e 'Dpkg::Progress-Fancy "1";\nAPT::Color "1";' >> /etc/apt/apt.conf.d/99progress

### Install packages to allow apt to use a repository over HTTPS
apt update && apt install apt-transport-https ca-certificates curl software-properties-common haproxy

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

add-apt-repository ppa:vbernat/haproxy-2.0 -y

apt update

apt install -y avahi-daemon libnss-mdns traceroute htop httpie bash-completion haproxy ruby docker-ce

systemctl stop haproxy

tee /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384

frontend scaler
    bind *:6443
    mode tcp
    log global
    option tcplog
    timeout client 3600s
    backlog 4096
    maxconn 50000
    use_backend masters

backend masters
    mode  tcp
    option log-health-checks
    option redispatch
    option tcplog
    balance roundrobin
    timeout connect 1s
    timeout queue 5s
    timeout server 3600s
EOF

i=0
for mips in ${MASTER_IPS}; do
  echo "    server master-${i} ${mips}:6443 check" >> /etc/haproxy/haproxy.cfg
  ((i++))
done

cat /vagrant/hosts.out >> /etc/hosts

systemctl restart haproxy