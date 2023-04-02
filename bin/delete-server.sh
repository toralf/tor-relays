#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x


function action() {
  sed -i -e "/^$1 /d" ~/.ssh/known_hosts
  hcloud server delete "$1"
}


#######################################################################
set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

project=${1?project missing}
hcloud context use ${project}
shift

export -f action
forks=$(grep "^forks" $(dirname $0)/../ansible.cfg | sed 's,.*= *,,g')
if ! echo ${@} | xargs -r -P ${forks} -n 1 bash -c 'action "$1"'; then
  echo -e "\n\n CHECK OUTPUT ^^^\n\n"
fi

echo
$(dirname $0)/update-dns.sh ${project}
