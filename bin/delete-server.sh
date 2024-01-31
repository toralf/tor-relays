#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud

if [[ $# -eq 0 ]]; then
  echo "no arguments given" >&2
  exit 1
fi

project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}\n"

jobs=$((2 * $(nproc)))

echo -e " deleting config(s) ..."
while read -r name; do
  sed -i -e "/^${name} /d" -e "/^${name},/d" ~/.ssh/known_hosts 2>/dev/null
  sed -i -e "/^${name} /d" -e "/^${name}$/d" ~/tmp/${project}_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/${project}_bridgeline 2>/dev/null
  if grep -q "^    ${name}:$" $(dirname $0)/../inventory/*.yaml 2>/dev/null; then
    # delete host from inventory only if it has no specific vars
    if ! grep -A 1 "^    ${name}:$" $(dirname $0)/../inventory/*.yaml | tail -n 1 | grep -q '^      '; then
      sed -i -e "/^    ${name}:$/d" $(dirname $0)/../inventory/*.yaml
    fi
  fi
  rm -f $(dirname $0)/../.ansible_facts/${name}
  sudo -- sed -i -e "/ \"${name} /d" -e "/ ${name}\"$/d" /etc/unbound/hetzner-${project}.conf
done < <(xargs -n 1 <<<$*)

echo -e "\n deleting server(s) at Hetzner ..."
xargs -t -r -P ${jobs} -n 1 hcloud --poll-interval 2s server delete <<<$* 1>/dev/null

echo -e "\n reloading DNS resolver" >&2
sudo rc-service unbound reload
