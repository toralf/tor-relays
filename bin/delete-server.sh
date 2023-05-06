#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

while read -r name; do
  if hcloud server describe $name 2>&1 | grep -e "^Name:" -e "^Status:" -e "^Created:" -e "^    IP:"; then
    echo
    ssh -n $name "/usr/sbin/service tor stop" || true
    hcloud server delete $name
    echo
  fi
  sed -i -e "/^$name /d" ~/.ssh/known_hosts
done < <(xargs -n 1 <<<$*)

echo
$(dirname $0)/update-dns.sh
