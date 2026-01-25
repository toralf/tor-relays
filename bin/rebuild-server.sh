#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   ./bin/rebuild-server.sh foo bar

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..
source ./bin/lib.sh

type hcloud jq >/dev/null

[[ $# -ne 0 ]]
setProject

jobs=24

names=$(xargs -r -n 1 <<<$*)

echo -e " rebuilding $(wc -w <<<${names}) system/s ..."

./bin/distrust-host-ssh-key.sh ${names}
cleanLocalDataEntries ${names}

snapshots=$(getSnapshots)

commands=$(
  while read -r name; do
    if [[ -n ${HCLOUD_IMAGE-} ]]; then
      image=${HCLOUD_IMAGE}
    else
      image=$(setImage ${name})
    fi
    echo --poll-interval $((1 + jobs / 2))s server rebuild --image ${image} ${name}
  done <<<${names}
)

echo -e " rebuilding ..."
xargs -r -P ${jobs} -L 1 hcloud --quiet <<<${commands}

./bin/trust-host-ssh-key.sh ${names}
