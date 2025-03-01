#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#  ./rebuild-server.sh foo bar

set -euf
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

echo -e "\n rebuilding ..."
xargs -t -r -P ${jobs} -n 1 hcloud --quiet server rebuild --image ${HCLOUD_IMAGE:-$debian} <<<$*

while ! xargs -r $(dirname $0)/trust-host-ssh-key.sh <<<$*; do
  echo -e "\n waiting 5 sec ...\n"
  sleep 5
  echo
done
