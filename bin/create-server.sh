#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

cax11_id=$(hcloud server-type list --output json | jq -cr '.[] | select(.name=="cax11") | .id') # prefer arm64
cax11_locations=$(hcloud datacenter list --output json | jq -cr '.[] | select(.server_types.available | contains(['$cax11_id'])) | .location.name')
all_locations=$(hcloud location list --output json | jq -cr '.[].name')

while read -r name; do
  loc=$(shuf -n 1 <<<$all_locations)
  [[ " $cax11_locations " =~ " $loc " ]] && model="cax11" || model="cpx11"
  echo "--name $name --location $loc --type $model"
done < <(xargs -n 1 <<<$*) |
  xargs -r -P $(nproc) -I {} hcloud server create --image "debian-11" --ssh-key "id_ed25519.pub" --poll-interval {}

echo
$(dirname $0)/update-dns.sh

echo -n ' wait ...'
sleep 20
echo
$(dirname $0)/add-to-known_hosts.sh $*
