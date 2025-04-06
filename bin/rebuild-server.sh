#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   ./rebuild-server.sh foo bar

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

jobs=$((3 * $(nproc)))
[[ ${jobs} -gt 48 ]] && jobs=48

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
xargs -n 1 <<<$* |
  while read -r name; do
    if [[ -n ${HCLOUD_IMAGE-} ]]; then
      echo ${HCLOUD_IMAGE} ${name}
    else
      if image=$(hcloud server describe ${name} --output json | jq -r '.image.id'); then
        echo ${image} ${name}
      fi
    fi
  done  |
  xargs -r -P ${jobs} -L 1 hcloud --quiet server rebuild --image

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
