#!/bin/bash
# set -x

set -euf
export LANG=C.utf8

project=${1:?}
shift

hcloud context use ${project}

for name in ${@}
do
  hcloud server delete "${name}"
  sed -i -e "/^${name} /d" ~/.ssh/known_hosts
done

$(dirname $0)/update-dns.sh ${project}
