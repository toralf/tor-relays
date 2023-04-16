#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x


set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]
project=$(hcloud context active 1>/dev/null)
[[ -n $project ]]

while read -r i
do
  if hcloud server describe $i &>/dev/null; then
    hcloud server delete $i
  fi
done < <(xargs -n 1 <<< $@)

while read -r i
do
  sed -i -e "/^$i /d" ~/.ssh/known_hosts
done < <(xargs -n 1 <<< $@)

echo
$(dirname $0)/update-dns.sh ${project}
