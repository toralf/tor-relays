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

# choose both ARM (cax11) and AMD (cpx11) systems
# 3 of 5 location provide currently ARM, prefer a 50:50 distribution of AMD and ARM:   3/5 x 5/6 = 1/2
cax11_id=$(hcloud server-type list --output json | jq -r '.[] | select(.name=="cax11") | .id')
cax11_locations=$(hcloud datacenter list --output json | jq -r '.[] | select(.server_types.available | contains(['${cax11_id}'])) | .location.name' | xargs)
all_locations=$(hcloud location list --output json | jq -r '.[].name')
os_version=$(hcloud image list --type system --output columns=name | grep '^debian' | sort -ur | head -n 1) # choose latest Debian
ssh_key=$(hcloud ssh-key list --output json | jq -r '.[].name' | head -n 1)

while read -r name; do
  loc=$(xargs -n 1 <<<${all_locations} | shuf -n 1) # dice a location
  if [[ ${cax11_locations} =~ ${loc} && $((RANDOM % 6)) -lt 5 ]]; then
    type="cax11"
  else
    type="cpx11"
  fi
  echo "server create --image ${HCLOUD_OS_VERSION:-$os_version} --ssh-key ${HCLOUD_SSH_KEY:-$ssh_key} --poll-interval 2s --name ${name} --location ${HCLOUD_LOCATION:-$loc} --type ${HCLOUD_TYPE:-$type}"
done < <(xargs -n 1 <<<$*) |
  xargs -r -P ${jobs} -L 1 hcloud

echo -e "\n update DNS ..."
$(dirname $0)/update-dns.sh

echo -e "\n adding to ~/.ssh/known_hosts ..."
while ! $(dirname $0)/add-to-known_hosts.sh $*; do
  echo -en "\n wait few sec before retry ..."
  sleep 10
  echo
done
