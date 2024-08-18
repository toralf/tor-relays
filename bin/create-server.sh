#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g. ./create-server.sh $(seq -w 0 9 | xargs -n 1 printf "foo%i ")

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}\n"

jobs=$((2 * $(nproc)))

# Architecture: get available locations
data_centers=$(hcloud datacenter list --output json | jq -r '.[] | select(.location.name != "sin")')
locations=$(hcloud location list --output json | jq -r '.[] | select(.name != "sin")')

server_types=$(hcloud server-type list --output json)
cax11_id=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${server_types})
cpx11_id=$(jq -r '.[] | select(.name=="cpx11") | .id' <<<${server_types})
cx22_id=$(jq -r '.[] | select(.name=="cx22") | .id' <<<${server_types})

cax11_locations=$(jq -r '.[] | select(.server_types.available | contains(['${cax11_id}'])) | .location.name' <<<${data_centers})
cpx11_locations=$(jq -r '.[] | select(.server_types.available | contains(['${cpx11_id}'])) | .location.name' <<<${data_centers})
cx22_locations=$(jq -r '.[] | select(.server_types.available | contains(['${cx22_id}'])) | .location.name' <<<${data_centers})
used_locations=$(jq -r '.[].name' <<<${locations})

# OS: use latest Debian
image_list=$(hcloud image list --type system --output columns=name)
debian=$(grep '^debian' <<<${image_list} | sort -ur | head -n 1)

ssh_keys=$(hcloud ssh-key list --output json)
ssh_key=$(jq -r '.[].name' <<<${ssh_keys} | head -n 1)

if [[ -z ${used_locations} || -z ${cax11_locations} || -z ${cpx11_locations} || -z ${cx22_locations} || -z ${debian} || -z ${ssh_key} ]]; then
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

    echo "server create --image ${HCLOUD_IMAGE:-$debian} --ssh-key ${ssh_key} --name ${name} --location ${loc} --type ${htype}"
  done |
  xargs -t -r -P ${jobs} -L 1 hcloud --quiet

$(dirname $0)/update-dns.sh

diff=$((EPOCHSECONDS - now))
if [[ $diff -lt 30 ]]; then
  echo -en "\n wait $diff sec before continue ..."
  sleep $((30 - diff))
fi

while ! xargs -r $(dirname $0)/trust-host-ssh-key.sh <<<$*; do
  echo -e "\n wait 5 sec before retry ...\n"
  sleep 5
  echo
done
