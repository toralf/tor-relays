#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   ./bin/delete-server.sh foo bar

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..
source ./bin//lib.sh

type hcloud rc-service >/dev/null

[[ $# -ne 0 ]] || exit 1
setProject

jobs=32

names=$(xargs -r -n 1 <<<$*)

echo -e " deleting $(wc -w <<<${names}) system/s ..."

./bin/distrust-host-ssh-key.sh ${names}

cleanLocalDataFiles ${names}
cleanLocalDataEntries ${names}

echo " delete from DNS config ..."
while read -r name; do
  sudo -- sed -i -e "/ \"${name} /d" -e "/ ${name}\"$/d" /etc/unbound/hetzner-${project}.conf
done <<<${names}

echo " reloading DNS resolver ..."
sudo rc-service unbound reload

echo " deleting systems ..."
set +e
xargs -r -P ${jobs} -n 10 timeout 2m hcloud --quiet --poll-interval 5s server delete <<<${names} 2>/dev/null
rc=$?
set -e

echo " rc=${rc}"
if [[ ${rc} -eq 0 || ${rc} -eq 123 ]]; then
  echo " OK"
else
  echo " NOT ok"
  exit ${rc}
fi
