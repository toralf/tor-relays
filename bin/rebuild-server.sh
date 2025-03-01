#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#  ./rebuild-server.sh foo bar

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}\n"

jobs=$((2 * $(nproc)))

# default OS: recent Debian
image_list=$(hcloud image list --type system --output columns=name)
debian=$(grep '^debian' <<<${image_list} | sort -ur --version-sort | head -n 1)

xargs -r $(dirname $0)/distrust-host-ssh-key.sh <<<$*

# wellknown entries must be cleaned manually
echo -e " deleting local facts ..."
while read -r name; do
  sed -i -e "/^${name} /d" -e "/^${name}$/d" -e "/^${name}:[0-9]*$/d" -e "/\"${name}:[0-9]*\"/d" ~/tmp/*_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/*_bridgeline 2>/dev/null
  rm -f $(dirname $0)/../.ansible_facts/${name}
done < <(xargs -n 1 <<<$*)

echo -e "\n rebuilding ..."
xargs -t -r -P ${jobs} -n 1 hcloud --quiet server rebuild --image ${HCLOUD_IMAGE:-$debian} <<<$*

while ! xargs -r $(dirname $0)/trust-host-ssh-key.sh <<<$*; do
  echo -e "\n waiting 5 sec ...\n"
  sleep 5
  echo
done
