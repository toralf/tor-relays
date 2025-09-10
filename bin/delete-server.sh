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

cleanLocalDataFiles $*
cleanLocalDataEntries $*

echo " delete from DNS config ..."
while read -r name; do
  sudo -- sed -i -e "/ \"${name} /d" -e "/ ${name}\"$/d" /etc/unbound/hetzner-${project}.conf
done < <(xargs -n 1 <<<$*)

echo " reloading DNS resolver ..."
sudo rc-service unbound reload

$(dirname $0)/distrust-host-ssh-key.sh $*

echo -e " deleting $(wc -w <<<$*) system/s: $(cut -c -16 <<<$*)..."

set +e
xargs -r -P ${jobs} -n 10 hcloud --quiet --poll-interval 12s server delete <<<$* 2>/dev/null
rc=$?
set -e
[[ ${rc} == 123 ]] && exit 0 || exit ${rc}
