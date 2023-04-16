#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

if [[ $# -lt 2 ]]; then
  echo "at least 2 parameters are expected"
  exit 1
fi

project=$1
hcloud context use ${project}
shift

while read -r i
do
  hcloud server delete $i || true
  sed -i -e "/^$i /d" ~/.ssh/known_hosts
done < <(xargs -n 1 <<< $@)

echo
$(dirname $0)/update-dns.sh ${project}
