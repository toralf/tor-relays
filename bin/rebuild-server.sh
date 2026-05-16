#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# This is a wrapper of "hcloud server crrebuildeate ..."

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

names=$(xargs -n 1 <<<$*)

echo -e " rebuilding $(wc -w <<<${names}) system/s ..."

./bin/distrust-host-ssh-key.sh ${names}
cleanLocalDataEntries ${names}

snapshots=$(getSnapshots)

commands=$(
  while read -r name; do
    image=$(getImage ${name})
    echo --poll-interval $((1 + jobs / 2))s server rebuild --image ${image} ${name}
  done <<<${names}
)

# the API call to Hetzner
echo -e " rebuilding ..."
set +e
xargs -r -P ${jobs} -L 1 hcloud --quiet <<<${commands}
rc=$?
set -e

echo " rc=${rc}"
if [[ ${rc} -eq 0 || ${rc} -eq 123 ]]; then
  ./bin/trust-host-ssh-key.sh ${names}
else
  echo " NOT ok" >&2
  exit ${rc}
fi
