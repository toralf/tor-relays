#!/bin/bash
#set -x

set -euf
export LANG=C.utf8

# set Hetzner project
project=${1:?}
hcloud context use ${project}
shift

for name in ${@}
do
  hcloud server delete "${name}"
  sed -i -e "/^${name} /d" ~/.ssh/known_hosts
done

# update /etc/unbound/hetzner-${project}.conf
$(dirname $0)/update-dns.sh ${project}
