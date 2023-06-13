#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n ${project} ]]

jobs=$((1 * $(nproc)))

echo -n " stopping tor service(s) ..."
if xargs -n 1 <<<$* | xargs -r -P ${jobs} -I {} ssh -n -oConnectTimeout=2 -oConnectionAttempts=1 {} "service tor stop &>/dev/null 1>/dev/null || true"; then
  echo
  sleep 5
fi

echo -n " delete from ~/.ssh/known_hosts and tmp files ... "
while read -r name; do
  set +e
  sed -i -e "/^${name} /d" ~/.ssh/known_hosts ~/tmp/public_{bto,clients,onionoo,uname,uptime,version}
  sed -i -e "/ # ${name}$/d" /tmp/public_bridgeline
  rm -f $(dirname $0)/../.ansible_facts/${name}
  set -e
done < <(xargs -n 1 <<<$*)
echo

echo -n " deleting server(s) ..."
if xargs -r -n 1 -P ${jobs} hcloud server delete 1>/dev/null <<<$*; then
  echo
fi

echo
$(dirname $0)/update-dns.sh
