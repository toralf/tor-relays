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

all_locations=$(hcloud location list --output json | jq -r '.[].name')
cx11_id=$(hcloud server-type list --output json | jq -r '.[] | select(.name=="cx11") | .id')
cx11_locations=$(hcloud datacenter list --output json | jq -r '.[] | select(.server_types.available | contains(['${cx11_id}'])) | .location.name' | xargs)
cax11_id=$(hcloud server-type list --output json | jq -r '.[] | select(.name=="cax11") | .id')
cax11_locations=$(hcloud datacenter list --output json | jq -r '.[] | select(.server_types.available | contains(['${cax11_id}'])) | .location.name' | xargs)
os_version=$(hcloud image list --type system --output columns=name | grep '^debian' | sort -ur | head -n 1) # choose latest Debian
ssh_key=$(hcloud ssh-key list --output json | jq -r '.[].name' | head -n 1)

now=${EPOCHSECONDS}

# prefer smallest type
while read -r name; do
  if [[ -n ${HCLOUD_TYPE-} ]]; then
    type=$(xargs -n 1 <<<${HCLOUD_TYPE} | shuf -n 1)
  elif [[ ${name} =~ "-amd" ]]; then
    type="cpx11"
  elif [[ ${name} =~ "-arm" ]]; then
    type="cax11"
  elif [[ ${name} =~ "-int" ]]; then
    type="cx11"
  else
    type=$(xargs -n 1 <<<"cpx11 cax11 cx11" | shuf -n 1)
  fi

  if [[ ${type} == "cx11" ]]; then
    loc=$(xargs -n 1 <<<${HCLOUD_LOCATIONS:-$cx11_locations} | shuf -n 1)
  elif [[ ${type} == "cax11" ]]; then
    loc=$(xargs -n 1 <<<${HCLOUD_LOCATIONS:-$cax11_locations} | shuf -n 1)
  else
    loc=$(xargs -n 1 <<<${HCLOUD_LOCATIONS:-$all_locations} | shuf -n 1)
  fi

  echo "server create --image ${os_version} --ssh-key ${ssh_key} --name ${name} --location ${loc} --type ${type}"
done < <(xargs -n 1 <<<$*) |
  xargs -t -r -P ${jobs} -L 1 hcloud --quiet

$(dirname $0)/update-dns.sh

diff=$((EPOCHSECONDS - now))
if [[ $diff -lt 30 ]]; then
  echo -en "\n wait $diff sec before continue ..."
  sleep $((35 - diff))
fi

while ! $(dirname $0)/add-to-known_hosts.sh $*; do
  echo -e "\n wait 10 sec before retry ...\n"
  sleep 10
  echo
done
