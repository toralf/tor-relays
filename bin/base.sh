#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# creates secrets and local dirs

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

local_inventory=$(dirname $0)/../inventory/local.yaml
if [[ ! -s ${local_inventory} ]]; then
  cat <<EOF >${local_inventory}
---
# created by $0 at $(date)

# 2x vCPU
all:
  vars:
    jobs: $((2 * $(nproc)))
EOF
  chmod 600 ${local_inventory}
fi

# info files go to ~/tmp, CA and ecrtificates to ./secrets within this repo
mkdir -p ${HOME}/tmp/{kconfigs,issues} $(dirname $0)/../secrets/ssl/{CA,clients}/{certs,csrs,keys}
