#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x


function action() {
  hcloud server create \
      --image "debian-11" \
      --ssh-key "tfoerste@t44" \
      --location "$(shuf -n 1 <<< ${loc_list})" \
      --type "cpx11" \
      --name "$1" \
      --poll-interval 1s 1>/dev/null
  echo -n " $1 "
}


#######################################################################
set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

project=${1?project missing}
hcloud context use ${project}
shift

loc_list=$(hcloud location list | awk 'NR > 1 { print $2 }')

export -f action
forks=$(grep "^forks" $(dirname $0)/../ansible.cfg | sed 's,.*= *,,g')
if ! echo ${@} | xargs -r -P ${forks} -n 1 bash -c "action $1"; then
  echo -e "\n\n CHECK OUTPUT ^^^\n\n"
fi

echo
$(dirname $0)/update-dns.sh ${project}

sleep 15

echo
$(dirname $0)/add-to-known_hosts.sh ${@}
