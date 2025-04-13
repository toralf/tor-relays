#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   ./rebuild-server.sh foo bar

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin
source $(dirname $0)/lib.sh

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

jobs=$((3 * $(nproc)))
[[ ${jobs} -gt 48 ]] && jobs=48

# default OS: recent Debian
image_default=$(hcloud image list --type system --output json | jq -r '.[].name' | grep '^debian' | sort -urV | head -n 1)

echo -e " rebuilding $(wc -w <<<$*) system/s: $(cut -c -16 <<<$*)..."
xargs -n 1 <<<$* |
  while read -r name; do
    if [[ -n ${HCLOUD_IMAGE-} ]]; then
      echo ${HCLOUD_IMAGE} ${name}
    else
      if read -r image < <(hcloud server describe ${name} --output json | jq -r '.image.id'); then
        echo ${image:-$image_default} ${name}
      fi
    fi
  done |
  xargs -r -P ${jobs} -L 1 hcloud --quiet --poll-interval 30s server rebuild --image

cleanLocalData $*

# clean up any left over SSH key
$(dirname $0)/distrust-host-ssh-key.sh $*

# build SSH trust relationship
$(dirname $0)/trust-host-ssh-key.sh $*
