#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8

project=${1:?}
shift

hcloud context use ${project}

# create at an arbitrarily chosen Hetzner location
loc_list=$(hcloud location list | awk 'NR > 1 { print $2 }')

i=0
for name in ${@}
do
  ((++i))
  echo -e " ${i}#$#\tname: ${name}\n"
  hcloud server create \
      --image "debian-11" \
      --ssh-key "tfoerste@t44" \
      --location "$(shuf -n 1 <<< ${loc_list})" \
      --type "cpx11" \
      --name "${name}"
done

echo
$(dirname $0)/update-dns.sh ${project}

echo
$(dirname $0)/add-to-known_hosts.sh ${@}
