#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n $project ]]

echo -n " stopping tor service(s) ..."
xargs -n 1 <<<$* | xargs -r -P $(nproc) -I {} ssh {} "service tor stop &>/dev/null || true" 1>/dev/null
echo

echo -n " delete from ~/.ssh/known_hosts ... "
while read -r name; do
  sed -i -e "/^$name /d" ~/.ssh/known_hosts
done < <(xargs -n 1 <<<$*)
echo

sleep 5

echo -n " deleting server(s) ..."
xargs -r -n 1 -P $(nproc) hcloud server delete 1>/dev/null <<<$*
echo

echo
$(dirname $0)/update-dns.sh
