#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8

project=${1:?}
shift

hcloud context use ${project}

i=0
for name in ${@}
do
  ((++i))
  echo -e " ${i}#$#\tname: ${name}\n"
  set +e
  hcloud server delete "${name}"
  sed -i -e "/^${name} /d" ~/.ssh/known_hosts
  set -e
done

echo
$(dirname $0)/update-dns.sh ${project}
