#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

locations=$(hcloud location list --output columns=name | awk '{ if (NR > 1) { print $1 } }')

while read -r i; do
  if ! hcloud server describe $i 2>/dev/null | grep -e "^Name:" -e "^Status:" -e "^Created:" -e "^    IP:"; then
    loc=$(shuf -n 1 <<<${locations})
    case $loc in
    fsn1) size="cax11" ;;
    *) size="cpx11" ;;
    esac
    echo "$loc $size"
    hcloud server create --name $i --location $loc --image "debian-11" --ssh-key "id_ed25519.pub" --type $size --poll-interval 2s
    echo
  fi
done < <(xargs -n 1 <<<$*)

echo
$(dirname $0)/update-dns.sh

echo -n 'add to known_hosts '
for i in $(seq 1 15); do
  echo -n '.'
  sleep 1
done
echo
$(dirname $0)/add-to-known_hosts.sh $*
