#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x


function action() {
  ssh -q -oStrictHostKeyChecking=accept-new -oConnectTimeout=1 -oConnectionAttempts=6 $1 "uname -a" </dev/null >/dev/null
  echo -n " $1 "
}


set -euf
export LANG=C.utf8

forks=$(grep "^forks" $(dirname $0)/../ansible.cfg | sed 's,.*= *,,g')

export -f action
if ! echo ${@} | xargs -r -P ${forks} -n 1 bash -c 'action "$1"' _; then
  echo -e "\n\n CHECK OUTPUT ^^^\n\n"
fi
