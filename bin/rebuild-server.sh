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

jobs=$((3 * $(nproc)))
[[ ${jobs} -gt 48 ]] && jobs=48

if [[ ${LOOKUP_SNAPSHOT-} != "n" ]]; then
  setSnapshots
fi

echo -e " rebuilding $(wc -w <<<$*) system/s: $(cut -c -16 <<<$*)..."
xargs -n 1 <<<$* |
  while read -r name; do
    setImage
    [[ ${image} =~ ^[0-9]+$ ]] && poll_interval="45s" || poll_interval="10s"
    echo --poll-interval ${poll_interval} server rebuild --image ${image} ${name}
  done |
  xargs -r -P ${jobs} -L 1 hcloud --quiet

cleanLocalDataEntries $*

# clean up any left over SSH key
$(dirname $0)/distrust-host-ssh-key.sh $*

# build SSH trust relationship
$(dirname $0)/trust-host-ssh-key.sh $*
