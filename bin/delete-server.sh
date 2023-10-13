#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

jobs=$((1 * $(nproc)))

echo -e "\n delete known ssh key(s), .ansible_facts and line(s) in tmp files ... "
while read -r name; do
  sed -i -e "/^${name} /d" -e "/^${name},/d" ~/.ssh/known_hosts 2>/dev/null
  sed -i -e "/^${name} /d" -e "/^${name}$/d" ~/tmp/${project}_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/${project}_bridgeline 2>/dev/null
  rm -f $(dirname $0)/../.ansible_facts/${name}
done < <(xargs -n 1 <<<$*)

echo -e "\n delete server(s) ..."
xargs -r -P ${jobs} -n 1 hcloud server delete <<<$*

echo -e "\n update DNS IPv4 ..."
$(dirname $0)/update-dns.sh
echo -e "\n update DNS IPv6 ..."
$(dirname $0)/update-dns.sh -6
