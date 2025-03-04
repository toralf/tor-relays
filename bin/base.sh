#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# creates secrets and local dirs once

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

secrets=$(dirname $0)/../secrets/local.yaml

if [[ ! -s ${secrets} ]]; then
  cat <<EOF >${secrets}
---
# created by $0 at $(date)

seed_address: "$(base64 </dev/urandom | tr -d '+/=' | head -c 32)"
seed_metrics: "$(base64 </dev/urandom | tr -d '+/=' | head -c 32)"
seed_tor_port: "$(base64 </dev/urandom | tr -d '+/=' | head -c 32)"

EOF
  chmod 400 ${secrets}
fi

local_inventory=$(dirname $0)/../inventory/all.yaml
if [[ ! -s ${local_inventory} ]]; then
  cat <<EOF >${local_inventory}
---
# created by $0 at $(date)

# for localhost set upper job count to vCPU count
all:
  vars:
    # throttle Git API calls
    torproject_connections: 20
    # base for various pseudo-randomzied settings
    seed_host: "{{ inventory_hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address }}"

EOF
  chmod 600 ${local_inventory}
fi

# issue files go to ~/tmp, Root CA and certificates to ./secrets in this repo
mkdir -p ${HOME}/tmp/{ddos,kconfigs,issues} $(dirname $0)/../secrets/ssl/{CA,clients}/{certs,csrs,keys}
