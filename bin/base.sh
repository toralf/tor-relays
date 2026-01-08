#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# creates secrets and local dirs once

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..
secrets=./secrets/local.yaml

if [[ ! -s ${secrets} ]]; then
  cat <<EOF >${secrets}
---
# created by $0 at $(date)

seed_address: "$(base64 </dev/urandom | tr -d '+/=' | head -c 32)"
seed_metrics: "$(base64 </dev/urandom | tr -d '+/=' | head -c 32)"
seed_torport: "$(base64 </dev/urandom | tr -d '+/=' | head -c 32)"

EOF
  chmod 400 ${secrets}
fi

local_inventory=./inventory/all.yaml
if [[ ! -s ${local_inventory} ]]; then
  cat <<EOF >${local_inventory}
---
# created by $0 at $(date)

all:
  vars:
    # throttle local processes
    concurrent_local_jobs: $(nproc)
    # seed for various system-specific pseudo-randomized settings
    seed_host: "{{ inventory_hostname + ansible_facts.default_ipv4.address }}"

    # where to store certificate materials
    ca_dir: "{{ role_path }}/../../../secrets/ca"
    # local directory for site-info files
    infodir: "{{ lookup('env', 'HOME') }}/tmp/tor-relays"

EOF
  chmod 600 ${local_inventory}
fi

# Root CA and certificates are stored under ./secrets
mkdir -p ${HOME}/tmp/tor-relays/{artefact,coredump,ddos,ddos6,dmesg,kconfig,tor-keys,trace}
