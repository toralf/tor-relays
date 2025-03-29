#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud rc-service unbound

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

jobs=$((3 * $(nproc)))
[[ ${jobs} -gt 48 ]] && jobs=48

# wellknown entries are not cleaned
echo -e " deleting local system data, DNS and ssl ..."
while read -r name; do
  sed -i -e "/^${name} /d" -e "/^${name}$/d" -e "/^${name}:[0-9]*$/d" -e "/\"${name}:[0-9]*\"/d" ~/tmp/*_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/*_bridgeline 2>/dev/null
  rm -f $(dirname $0)/../.ansible_facts/${name}
  rm -f $(dirname $0)/../secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
  sudo -- sed -i -e "/ \"${name} /d" -e "/ ${name}\"$/d" /etc/unbound/hetzner-${project}.conf
done < <(xargs -n 1 <<<$*)

echo -e " deleting $(cut -c -16 <<<$*)..."
xargs -r -P ${jobs} -n 1 hcloud --quiet server delete <<<$*

echo -e " reloading DNS resolver ..." >&2
sudo rc-service unbound reload

xargs -r $(dirname $0)/distrust-host-ssh-key.sh <<<$*
