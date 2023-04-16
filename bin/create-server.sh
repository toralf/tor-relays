#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

loc_list=$(hcloud location list | awk 'NR > 1 { print $2 }')
while read -r i; do
  if ! hcloud server describe $i &>/dev/null; then
    hcloud server create \
      --name "$i" --location "$(shuf -n 1 <<<${loc_list})" \
      --image "debian-11" --ssh-key "tfoerste@t44" --type "cpx11" --poll-interval 1s
  fi
done < <(xargs -n 1 <<<$*)

echo
$(dirname $0)/update-dns.sh ${project}

for i in $(seq 1 15); do
  echo -n '.'
  sleep 1
done
echo
$(dirname $0)/add-to-known_hosts.sh ${@}
