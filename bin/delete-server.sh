#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

xargs -r -n 1 -P $(nproc) hcloud server delete &>/dev/null <<<$*
while read -r name; do
  sed -i -e "/^$name /d" ~/.ssh/known_hosts
done < <(xargs -n 1 <<<$*)

echo
$(dirname $0)/update-dns.sh
