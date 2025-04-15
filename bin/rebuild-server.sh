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

echo -e " rebuilding $(wc -w <<<$*) system/s: $(cut -c -16 <<<$*)..."

set -o pipefail
xargs -n 1 <<<$* |
  while read -r name; do
    if [[ -n ${HCLOUD_IMAGE-} ]]; then
      image=${HCLOUD_IMAGE}
    else
      image=$(hcloud server describe ${name} --output json | jq -r '.image.id')
      if [[ -z ${image} ]]; then
        echo " cannot get image id of ${name}" >&2
        exit 1
      fi
    fi
    echo ${image} ${name}
  done |
  xargs -r -P ${jobs} -L 1 hcloud --quiet --poll-interval 30s server rebuild --image

cleanLocalData $*

# clean up any left over SSH key
$(dirname $0)/distrust-host-ssh-key.sh $*

# build SSH trust relationship
$(dirname $0)/trust-host-ssh-key.sh $*
