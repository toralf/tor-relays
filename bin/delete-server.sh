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

# wellknown entries can't be cleaned b/c the hostname is on a separate line
echo -e " deleting local config ..."
while read -r name; do
  sed -i -e "/^${name} /d" -e "/^${name}$/d" -e "/^${name}:[0-9]*$/d" ~/tmp/*_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/*_bridgeline 2>/dev/null
  rm -f $(dirname $0)/../.ansible_facts/${name}
  rm -f $(dirname $0)/../secrets/ssl/clients/*/${name}.???
  sudo -- sed -i -e "/ \"${name} /d" -e "/ ${name}\"$/d" /etc/unbound/hetzner-${project}.conf
done < <(xargs -n 1 <<<$*)

if [[ ${SNAPSHOT_HALT_BEFORE:-0} -eq 1 || ${SNAPSHOT:-0} -eq 1 ]]; then
  if [[ ${SNAPSHOT_HALT_BEFORE:-0} -eq 1 ]]; then
    echo -e "\n shutdown ..."
    xargs -t -r -P ${jobs} -n 1 hcloud --quiet server shutdown <<<$*

    sleep 10

    echo -e "\n poweroff ..."
    xargs -t -r -P ${jobs} -n 1 hcloud --quiet server poweroff <<<$*
  fi

  echo -e "\n snapshot ..."
  xargs -t -r -P ${jobs} -I '{}' -n 1 hcloud --quiet server create-image --type snapshot --description "{}-${EPOCHSECONDS}" {} <<<$*
fi

echo -e "\n deleting ..."
xargs -t -r -P ${jobs} -n 1 hcloud --quiet server delete <<<$*

echo -e "\n reloading DNS resolver ..." >&2
sudo rc-service unbound reload

xargs -r $(dirname $0)/distrust-host-ssh-key.sh <<<$*
