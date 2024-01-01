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

jobs=$((2 * $(nproc)))

echo -e "\n delete ssh key(s), ansible facts, DNS entries and ansible generated tmp files ... "
while read -r name; do
  sed -i -e "/^${name} /d" -e "/^${name},/d" ~/.ssh/known_hosts 2>/dev/null
  sed -i -e "/^${name} /d" -e "/^${name}$/d" ~/tmp/${project}_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/${project}_bridgeline 2>/dev/null
  rm -f $(dirname $0)/../.ansible_facts/${name}
  sudo -- sed -i -e "/ \"${name} /d" -e "/ ${name}\"$/d" /etc/unbound/hetzner-${project}.conf
done < <(xargs -n 1 <<<$*)

echo -e "\n delete server(s) at Hetzner ..."
xargs -r -P ${jobs} -n 1 hcloud server delete <<<$*

echo -e "\n reloading DNS resolver" >&2
sudo rc-service unbound reload
