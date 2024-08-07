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

_data_centers=$(hcloud datacenter list --output json)
_server_types=$(hcloud server-type list --output json)
_locations=$(hcloud location list --output json)
_image_list=$(hcloud image list --type system --output columns=name)
_ssh_keys=$(hcloud ssh-key list --output json)

all_locations=$(jq -r '.[].name' <<<${_locations})
cax11_id=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${_server_types})
cax11_locations=$(jq -r '.[] | select(.server_types.available | contains(['${cax11_id}'])) | .location.name' <<<${_data_centers} | xargs)
cpx11_id=$(jq -r '.[] | select(.name=="cpx11") | .id' <<<${_server_types})
cpx11_locations=$(jq -r '.[] | select(.server_types.available | contains(['${cpx11_id}'])) | .location.name' <<<${_data_centers} | xargs)
cx22_id=$(jq -r '.[] | select(.name=="cx22") | .id' <<<${_server_types})
cx22_locations=$(jq -r '.[] | select(.server_types.available | contains(['${cx22_id}'])) | .location.name' <<<${_data_centers} | xargs)
debian=$(grep '^debian' <<<${_image_list} | sort -ur | head -n 1) # choose latest Debian
ssh_key=$(jq -r '.[].name' <<<${_ssh_keys} | head -n 1)

if [[ -z ${all_locations} || -z ${cax11_locations} || -z ${cpx11_locations} || -z ${cx22_locations} || -z ${debian} || -z ${ssh_key} ]]; then
  echo "API query failed" >&2
  exit 1
fi

now=${EPOCHSECONDS}

# prefer smallest type
xargs -n 1 <<<$* |
  while read -r name; do
    if [[ -n ${HCLOUD_TYPE-} ]]; then
      htype=$(xargs -n 1 <<<${HCLOUD_TYPE} | shuf -n 1)
    else
      case ${name} in
      *-amd-*) htype="cpx11" ;;
      *-arm-*) htype="cax11" ;;
      *-intel-*) htype="cx22" ;;
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
      loc=$(xargs -n 1 <<<${HCLOUD_LOCATION:-$all_locations} | shuf -n 1)
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

while ! $(dirname $0)/trust-host-ssh-key.sh $*; do
  echo -e "\n wait 5 sec before retry ...\n"
  sleep 5
  echo
done
