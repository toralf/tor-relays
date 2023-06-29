#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

jobs=$((1 * $(nproc)))

# choose the first one
ssh_key=$(hcloud ssh-key list --output json | jq -cr '.[].name' | head -n 1)

# 2 vCPU, prefer ARM
cax11_id=$(hcloud server-type list --output json | jq -cr '.[] | select(.name=="cax11") | .id') # prefer arm64
cax11_locations=$(hcloud datacenter list --output json | jq -cr '.[] | select(.server_types.available | contains(['${cax11_id}'])) | .location.name')
all_locations=$(hcloud location list --output json | jq -cr '.[].name')
os_version=$(hcloud image list -t system --output columns=name | grep '^debian' | sort -u | tail -n 1)

while read -r name; do
  loc=$(shuf -n 1 <<<${all_locations})
  [[ " ${cax11_locations} " =~ " ${loc} " ]] && model="cax11" || model="cpx11"
  echo "hcloud server create --image ${os_version} --ssh-key ${ssh_key} --poll-interval 2s --name ${name} --location ${loc} --type ${model}"
done < <(xargs -n 1 <<<$*) |
  xargs -r -P ${jobs} -I '{}' -t bash -c "{}"

echo -e "\n add to DNS ..."
$(dirname $0)/update-dns.sh

echo -e "\n wait 20 sec ..."
sleep 20
echo
$(dirname $0)/add-to-known_hosts.sh $*
