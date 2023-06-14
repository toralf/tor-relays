#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n ${project} ]]

jobs=$((1 * $(nproc)))

cax11_id=$(hcloud server-type list --output json | jq -cr '.[] | select(.name=="cax11") | .id') # prefer arm64
cax11_locations=$(hcloud datacenter list --output json | jq -cr '.[] | select(.server_types.available | contains(['${cax11_id}'])) | .location.name')
all_locations=$(hcloud location list --output json | jq -cr '.[].name')
os_version=$(hcloud image list -t system --output columns=name | grep '^debian' | sort -n | tail -n 1)

while read -r name; do
  loc=$(shuf -n 1 <<<${all_locations})
  [[ " ${cax11_locations} " =~ " ${loc} " ]] && model="cax11" || model="cpx11"
  echo "--name ${name} --location ${loc} --type ${model}"
done < <(xargs -n 1 <<<$*) |
  xargs -r -P ${jobs} -I {} bash -c "hcloud server create --image ${os_version} --ssh-key id_ed25519.pub --poll-interval 2s {}"

echo
$(dirname $0)/update-dns.sh

echo -n ' wait 15 sec ...'
sleep 15
echo
$(dirname $0)/add-to-known_hosts.sh $*
