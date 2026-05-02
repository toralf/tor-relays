#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

function sync_site() {
  if awk '/^PLAY RECAP/,/^$/' ${logprefix}.${site}.ansible.${tags}.log |
    grep -v -e "^PLAY RECAP" -e " changed=0 " | awk '{ print $0 }' | sort | xargs -r | grep -q .; then
    local srv
    for srv in $*; do
      info "  rsync ${site} to ${srv}"
      local dest="${srv}:/var/www/${site}"
      local log="${logprefix}.${site}.rsync.${srv}.log"
      echo -e "\n# epoch ${EPOCHSECONDS}\n# $(date -R)" >>${log}
      if ! rsync --verbose --recursive ~/tmp/hx/${site}/ ${dest} >>${log} 2>/dev/null; then
        info "  NOT ok" >&2
      fi
      if ! rsync --verbose ${log} ${dest} &>/dev/null; then
        info "  NOT ok" >&2
      fi
    done
  fi
}

#######################################################################
set -euf
set -m
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..
source ./hx/hx-lib.sh

if [[ ! -d ~/tmp/hx ]]; then
  mkdir -p ~/tmp/hx
fi
logprefix=~/tmp/hx/$(basename $0)
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP-INFO' INT QUIT TERM EXIT

info "pid $$"
pit_stop 0 STOP-INFO

while :; do
  site="site01"
  tags="coredump,trace"
  srvs="hm0-dt-arm-dist-x-x-0 hm0-dt-arm-dist-x-x-1"

  info "${site} ${tags}"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags ${tags} -e '{ "infodir": "~/tmp/hx/'${site}'" }' \
    -e '{ "issue_since": "12 hours ago" }' -e '{ "trace_since": "12 hours ago" }' &>${logprefix}.${site}.ansible.${tags}.log; then
    info "  NOT ok" >&2
  fi
  sync_site ${srvs}

  #--------------------------------------------------------------------
  site="site02"
  tags="artefact"
  srvs="hm1-dt-arm-dist-x-x-0 hm1-dt-arm-dist-x-x-1"

  info "${site} ${tags}"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags ${tags} -e '{ "infodir": "~/tmp/hx/'${site}'" }' \
    -e '{ "issue_since": "12 hours ago" }' -e '{ "trace_since": "12 hours ago" }' &>${logprefix}.${site}.ansible.${tags}.log; then
    info "  NOT ok" >&2
  fi
  sync_site ${srvs}

  #--------------------------------------------------------------------
  pit_stop 300 STOP-INFO
done
