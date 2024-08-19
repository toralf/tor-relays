#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# creates secrets and tmp dirs

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

mkdir -p ${HOME}/tmp/{kconfigs,issues}
