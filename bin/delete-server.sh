#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}\n"

jobs=$((2 * $(nproc)))

echo -e " deleting config(s) ..."
while read -r name; do
  if [[ -z ${name} ]]; then
    echo "Bummer!" >&2
    exit 1
  fi

  sed -i -e "/^${name} /d" -e "/^${name},/d" ~/.ssh/known_hosts 2>/dev/null
  sed -i -e "/^${name} /d" -e "/^${name}$/d" ~/tmp/${project}_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/${project}_bridgeline 2>/dev/null
  sed -i -e "/^  *${name}:$/d" $(dirname $0)/../inventory/*.yaml 2>/dev/null
  rm -f $(dirname $0)/../.ansible_facts/${name}
  sudo -- sed -i -e "/ \"${name} /d" -e "/ ${name}\"$/d" /etc/unbound/hetzner-${project}.conf
done < <(xargs -n 1 <<<$*)

echo -e "\n deleting server(s) at Hetzner ..."
xargs -t -r -P ${jobs} -n 1 hcloud --poll-interval 2s server delete <<<$* 1>/dev/null

echo -e "\n reloading DNS resolver" >&2
sudo rc-service unbound reload
