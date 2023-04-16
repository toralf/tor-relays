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

if [[ $# -lt 2 ]]; then
  echo "at least 2 parameters are expected"
  exit 1
fi

project=$1
hcloud context use ${project}
shift

export -f action
forks=$(grep "^forks" $(dirname $0)/../ansible.cfg | sed 's,.*= *,,g')
if ! echo ${@} | xargs -r -P ${forks} -n 1 bash -c "action $1"; then
  echo -e "\n\n CHECK OUTPUT ^^^\n\n"
  exit 1
fi

echo
$(dirname $0)/update-dns.sh ${project}
