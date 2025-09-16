#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   ./bin/delete-server.sh foo bar

set -u # no -ef here
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin
source $(dirname $0)/lib.sh

hash -r hcloud rc-service

[[ $# -ne 0 ]] || exit 1
setProject

jobs=24

names=$(xargs -n 1 <<<$*)

cleanLocalDataFiles ${names}
cleanLocalDataEntries ${names}

echo " delete from DNS config ..."
while read -r name; do
  sudo -- sed -i -e "/ \"${name} /d" -e "/ ${name}\"$/d" /etc/unbound/hetzner-${project}.conf
done <<<${names}

echo " reloading DNS resolver ..."
sudo rc-service unbound reload

$(dirname $0)/distrust-host-ssh-key.sh ${names}

echo -e " deleting $(wc -w <<<${names}) system/s ..."

set +e
xargs -r -P ${jobs} -n 10 hcloud --quiet --poll-interval 5s server delete <<<${names} 2>/dev/null
rc=$?
set -e
[[ ${rc} == 123 ]] && exit 0 || exit ${rc}
