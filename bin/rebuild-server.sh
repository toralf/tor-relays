#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   LOOKUP_SNAPSHOT=y ./bin/rebuild-server.sh foo bar

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..
source ./bin/lib.sh

hash -r hcloud jq

[[ $# -ne 0 ]]
setProject

jobs=24

names=$(xargs -n 1 <<<$*)

echo -e " rebuilding $(wc -w <<<${names}) system/s ..."

./bin/distrust-host-ssh-key.sh ${names}
cleanLocalDataEntries ${names}

if [[ ${LOOKUP_SNAPSHOT-} != "n" ]]; then
  snapshots=$(getSnapshots)
fi

commands=$(
  while read -r name; do
    image=$(setImage)
    echo --poll-interval $((1 + jobs / 2))s server rebuild --image ${image} ${name}
  done <<<${names}
)

xargs -r -P ${jobs} -L 1 hcloud --quiet <<<${commands}

./bin/trust-host-ssh-key.sh ${names}
