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

ssh_key=${HCLOUD_SSH_KEY:-$(hcloud ssh-key list --output json | jq -r '.[].name' | head -n 1)}

cax11_id=$(hcloud server-type list --output json | jq -r '.[] | select(.name=="cax11") | .id')
cax11_locations=$(hcloud datacenter list --output json | jq -r '.[] | select(.server_types.available | contains(['${cax11_id}'])) | .location.name')
all_locations=$(hcloud location list --output json | jq -r '.[].name')
os_version=$(hcloud image list -t system --output columns=name | grep '^debian' | sort -ur | head -n 1)

while read -r name; do
  loc=${HCLOUD_LOCATION:-$(shuf -n 1 <<<${all_locations})}
  # 2 vCPU, prefer ARM (cax11) over AMD (cpx11)
  if [[ ${cax11_locations} =~ ${loc} ]]; then
    model="cax11"
  else
    model="cpx11"
  fi
  echo "hcloud server create --image ${os_version} --ssh-key ${ssh_key} --poll-interval 2s --name ${name} --location ${loc} --type ${model}"
done < <(xargs -n 1 <<<$*) |
  xargs -r -P ${jobs} -I '{}' -t bash -c "{}"

echo -e "\n add to DNS ..."
$(dirname $0)/update-dns.sh

while :; do
  echo -e "\n wait 10 sec before getting ssh host key(s) ..."
  sleep 10
  if $(dirname $0)/add-to-known_hosts.sh $*; then
    break
  fi
done

echo
