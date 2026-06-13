#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: wrap "hcloud server create ..."

# e.g.:
#   ./bin/create-server.sh hm1-d13-x86-{{0..7},{a..f}}
#   HCLOUD_TYPE=cax11 ./bin/create-server.sh foo

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..
source ./bin/lib.sh

type hcloud jq >/dev/null

[[ $# -ne 0 ]]
setProject

jobs=24

names=$(xargs -n 1 <<<$*)

echo -e " creating $(wc -w <<<${names}) system/s ..."

if grep -Ev "^[a-z0-9\-]+$" <<<${names}; then
  echo " ^^ invalid hostname/s" >&2
  exit 2
fi

if [[ -n ${HCLOUD_SSH_KEY-} ]]; then
  ssh_key=${HCLOUD_SSH_KEY}
else
  # search for a labeled key, otherwise just take the first one
  ssh_key=$(hcloud --quiet ssh-key list --output json | jq -r '.[] | select(.labels.hx == "true") | .name')
  if [[ -z ${ssh_key} ]]; then
    ssh_key=$(hcloud --quiet ssh-key list --output json | jq -r '.[0].name')
  fi
fi
if [[ -z ${ssh_key} ]]; then
  echo "no ssh key" >&2
  exit 3
fi

snapshots=${HCLOUD_SNAPSHOTS-$(getSnapshots)}

commands=$(
  while read -r name; do
    if [[ -n ${HCLOUD_TYPE-} ]]; then
      htype=${HCLOUD_TYPE}
    else
      # set htype based on hostname (e.g. hm1-d13-x86)
      if htype=$(cut -f 3 -d '-' -s <<<${name}); then
        case ${htype} in
        arm) htype="cax11" ;;
        x86) htype="cx23" ;;
        esac
      fi
      if [[ -z ${htype} ]]; then
        htype=$(shuf -n 1 -e cax11 cx23)
      fi
    fi

    image=$(getImage ${name})
    if [[ -z ${image} ]]; then
      echo " ERROR: empty image for ${name}" >&2
      exit 1
    fi

    echo --poll-interval $((1 + jobs / 2))s server create --image ${image} --type ${htype} --ssh-key ${ssh_key} --name ${name}
  done <<<${names}
)

# the API call to Hetzner
set +e
xargs -r -P ${jobs} -L 1 hcloud --quiet <<<${commands}
rc=$?
set -e

echo " rc=${rc}"
if [[ ${rc} -eq 0 || ${rc} -eq 123 ]]; then
  echo " OK"
  ./bin/update-dns.sh
  ./bin/trust-host-ssh-key.sh ${names}
else
  echo " NOT ok" >&2
  exit ${rc}
fi
