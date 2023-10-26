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
echo -e "\n using Hetzner project ${project:?}"

jobs=$((1 * $(nproc)))

if [[ -n ${HCLOUD_SSH_KEY-} ]]; then
  ssh_key=${HCLOUD_SSH_KEY}
else
  ssh_key=$(hcloud ssh-key list --output json | jq -r '.[].name' | head -n 1)
fi
cax11_id=$(hcloud server-type list --output json | jq -r '.[] | select(.name=="cax11") | .id')
cax11_locations=$(hcloud datacenter list --output json | jq -r '.[] | select(.server_types.available | contains(['${cax11_id}'])) | .location.name' | xargs)
all_locations=$(hcloud location list --output json | jq -r '.[].name')
os_version=$(hcloud image list --type system --output columns=name | grep '^debian' | sort -ur | head -n 1)

while read -r name; do
  if [[ -n ${HCLOUD_LOCATION-} ]]; then
    loc=$(xargs -n 1 <<<${HCLOUD_LOCATION} | shuf -n 1)
  else
    loc=$(shuf -n 1 <<<${all_locations})
  fi
  # 2 vCPU, prefer ARM (cax11) over AMD (cpx11), if available in the choosen location
  if [[ " ${cax11_locations} " =~ ${loc} ]]; then
    type="cax11"
  else
    type="cpx11"
  fi
  echo "server create --image ${os_version} --ssh-key ${ssh_key} --poll-interval 2s --name ${name} --location ${loc} --type ${type}"
done < <(xargs -n 1 <<<$*) |
  xargs -r -P ${jobs} -L 1 hcloud

echo -e "\n update DNS IPv4 ..."
$(dirname $0)/update-dns.sh

echo -e "\n adding to ~/.ssh/known_hosts ..."
while ! $(dirname $0)/add-to-known_hosts.sh $*; do
  echo -en "\n wait few sec before retry ..."
  sleep 10
  echo
done

echo -e "\n update DNS IPv6 ..."
$(dirname $0)/update-dns.sh -6
