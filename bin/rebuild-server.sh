#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   ./rebuild-server.sh foo bar

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

jobs=$((3 * $(nproc)))
[[ ${jobs} -gt 48 ]] && jobs=48

# default OS: recent Debian
image_list=$(hcloud image list --type system --output noheader --output columns=name)
image_default=$(grep '^debian' <<<${image_list} | sort -ur --version-sort | head -n 1)

xargs -r $(dirname $0)/distrust-host-ssh-key.sh <<<$*

# wellknown entries are not cleaned
echo -e " deleting local system data ..."
while read -r name; do
  sed -i -e "/^${name} /d" -e "/^${name}$/d" -e "/^${name}:[0-9]*$/d" -e "/\"${name}:[0-9]*\"/d" ~/tmp/*_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/*_bridgeline 2>/dev/null
  rm -f $(dirname $0)/../.ansible_facts/${name}
done < <(xargs -n 1 <<<$*)

now=${EPOCHSECONDS}

echo -e " rebuilding $(wc -w <<<$*) system/s: $(cut -c -16 <<<$*)..."
xargs -r -P ${jobs} -n 1 hcloud --quiet server rebuild --image ${HCLOUD_IMAGE:-$image_default} <<<$*

# wait half a minute before ssh into the instance
diff=$((EPOCHSECONDS - now))
if [[ ${diff} -lt 30 ]]; then
  wait=$((30 - diff))
  echo -en "\n waiting ${wait} sec ..."
  sleep ${wait}
fi

while ! xargs -r $(dirname $0)/trust-host-ssh-key.sh <<<$*; do
  echo -e " waiting 5 sec ..."
  sleep 5
  echo
done
