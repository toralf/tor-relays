#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

cax11_id=$(hcloud server-type list --output json | jq -cr '.[] | select(.name=="cax11") | .id')  # prefer arm64
datacenter_list=$(hcloud datacenter list --output json)
locations=$(hcloud location list --output json | jq -cr '.[].name')

while read -r name; do
  if ! hcloud server describe $name 2>/dev/null | grep -e "^Name:" -e "^Status:" -e "^Created:" -e "^    IP:"; then
    loc=$(shuf -n 1 <<<$locations)
    model=$(jq -cr '.[] | select(.location.name == "'$loc'") | .server_types.available | if contains(['$cax11_id']) then "cax11" else "cpx11" end' <<<$datacenter_list)
    echo "$loc $model"
    hcloud server create --name $name --location $loc --image "debian-11" --ssh-key "id_ed25519.pub" --type $model --poll-interval 2s
    echo
  fi
done < <(xargs -n 1 <<<$*)

echo
$(dirname $0)/update-dns.sh

echo -n 'add to known_hosts '
for i in $(seq 1 12); do
  echo -n '.'
  sleep 1
done
echo
$(dirname $0)/add-to-known_hosts.sh $*
