#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x


function action() {
  ssh -oStrictHostKeyChecking=accept-new -oConnectTimeout=5 -oConnectionAttempts=3 $1 "uname -a" </dev/null >/dev/null
}


set -euf
export LANG=C.utf8

forks=$(grep "^forks" $(dirname $0)/../ansible.cfg | sed 's,.*= *,,g')

export -f action
if ! echo ${@} | xargs -r -P ${forks} -n 1 bash -c 'action "$1"' _; then
  echo -e "\n\n CHECK OUTPUT ^^^\n\n"
fi
