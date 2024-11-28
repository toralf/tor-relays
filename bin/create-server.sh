#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g. ./create-server.sh $(seq -w 0 9 | xargs -r -n 1 printf "foo%i ")

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}\n"

jobs=$((2 * $(nproc)))

# Architecture: exclude expensive ones
data_centers=$(
  hcloud datacenter list --output json |
    jq -r '.[] | select(.location.name != "ash" and .location.name != "hil" and .location.name != "sin")'
)

server_types=$(hcloud server-type list --output json)
cax11_id=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${server_types})
cpx11_id=$(jq -r '.[] | select(.name=="cpx11") | .id' <<<${server_types})
cx22_id=$(jq -r '.[] | select(.name=="cx22") | .id' <<<${server_types})

cax11_locations=$(jq -r 'select(.server_types.available | contains(['${cax11_id}'])) | .location.name' <<<${data_centers})
cpx11_locations=$(jq -r 'select(.server_types.available | contains(['${cpx11_id}'])) | .location.name' <<<${data_centers})
cx22_locations=$(jq -r 'select(.server_types.available | contains(['${cx22_id}'])) | .location.name' <<<${data_centers})
used_locations=$(echo ${cax11_locations} ${cpx11_locations} ${cx22_locations} | xargs -n 1 | sort -u)

# OS: use latest Debian
image_list=$(hcloud image list --type system --output columns=name)
debian=$(grep '^debian' <<<${image_list} | sort -ur | head -n 1)

ssh_keys=$(hcloud ssh-key list --output json)
ssh_key=$(jq -r '.[].name' <<<${ssh_keys} | head -n 1)

if [[ -z ${used_locations} || -z ${debian} || -z ${ssh_key} ]]; then
  echo "API query failed" >&2
  exit 1
fi

now=${EPOCHSECONDS}

xargs -n 1 <<<$* |
  while read -r name; do
    if [[ -n ${HCLOUD_TYPE-} ]]; then
      htype=$(xargs -n 1 <<<${HCLOUD_TYPE} | shuf -n 1)
    else
      # default: smallest type
      case ${name} in
      *-amd | *-amd-*) htype="cpx11" ;;
      *-arm | *-arm-*) htype="cax11" ;;
      *-intel | *-intel-*) htype="cx22" ;;
      *) htype=$(xargs -n 1 <<<"cax11 cpx11 cx22" | shuf -n 1) ;;
      esac
    fi

    if [[ ${htype} == "cax11" ]]; then
      loc=$(xargs -n 1 <<<${HCLOUD_LOCATION:-$cax11_locations} | shuf -n 1)
    elif [[ ${htype} == "cpx11" ]]; then
      loc=$(xargs -n 1 <<<${HCLOUD_LOCATION:-$cpx11_locations} | shuf -n 1)
    elif [[ ${htype} == "cx22" ]]; then
      loc=$(xargs -n 1 <<<${HCLOUD_LOCATION:-$cx22_locations} | shuf -n 1)
    else
      loc=$(xargs -n 1 <<<${HCLOUD_LOCATION:-$used_locations} | shuf -n 1)
    fi

    echo "echo server create --image ${HCLOUD_IMAGE:-$debian} --ssh-key ${ssh_key} --name ${name} --location ${loc} --type ${htype}"
  done |
  xargs -t -r -P ${jobs} -L 1 hcloud --quiet

$(dirname $0)/update-dns.sh

diff=$((EPOCHSECONDS - now))
if [[ $diff -lt 30 ]]; then
  wait=$((30 - diff))
  echo -en "\n waiting ${wait} sec ..."
  sleep ${wait}
fi

while ! xargs -r $(dirname $0)/trust-host-ssh-key.sh <<<$*; do
  echo -e "\n waiting 5 sec ...\n"
  sleep 5
  echo
done
