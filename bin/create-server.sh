#!/bin/bash
# set -x

set -euf
export LANG=C.utf8

project=${1:?}
shift

hcloud context use ${project}
loc_list=$(hcloud location list | awk 'NR > 1 { print $2 }')

# create at an arbitrarily chosen Hetzner location
for name in ${@}
do
  echo -e "\n name: ${name}\n"
  hcloud server create \
      --image "debian-11" \
      --ssh-key "tfoerste@t44" \
      --location "$(shuf -n1 <<< ${loc_list})" \
      --type "cpx11" \
      --name "${name}"
done

$(dirname $0)/update-dns.sh ${project}
$(dirname $0)/update-known_hosts.sh ${@}
