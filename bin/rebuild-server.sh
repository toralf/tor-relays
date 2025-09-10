#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   LOOKUP_SNAPSHOT=y ./bin/rebuild-server.sh foo bar

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin
source $(dirname $0)/lib.sh

hash -r hcloud jq

[[ $# -ne 0 ]]
setProject

jobs=24

if [[ ${LOOKUP_SNAPSHOT-} != "n" ]]; then
  snapshots=$(getSnapshots)
fi

echo -e " rebuilding $(wc -w <<<$*) system/s: $(cut -c -16 <<<$*)..."
xargs -n 1 <<<$* |
  while read -r name; do
    image=$(getImage)
    echo --poll-interval 12s server rebuild --image ${image} ${name}
  done |
  xargs -r -P ${jobs} -L 1 hcloud --quiet

cleanLocalDataEntries $*
$(dirname $0)/distrust-host-ssh-key.sh $*
$(dirname $0)/trust-host-ssh-key.sh $*
