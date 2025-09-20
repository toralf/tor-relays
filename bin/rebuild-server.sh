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

jobs=$(nproc)

names=$(xargs -n 1 <<<$*)

if [[ ${LOOKUP_SNAPSHOT-} != "n" ]]; then
  snapshots=$(getSnapshots)
fi

echo -e " rebuilding $(wc -w <<<${names}) system/s ..."
while read -r name; do
  image=$(getImage)
  echo --poll-interval $((1 + jobs / 2))s server rebuild --image ${image} ${name}
done <<<${names} |
  xargs -r -P ${jobs} -L 1 hcloud --quiet

cleanLocalDataEntries ${names}
$(dirname $0)/distrust-host-ssh-key.sh ${names}
$(dirname $0)/trust-host-ssh-key.sh ${names}
