#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

function sync_site() {
  local site=${1?SITE NOT GIVEN}
  shift
  local srvs=$(eval echo $*)

  if awk '/^PLAY RECAP/,/^$/' ${logprefix}.${site}.ansible.log |
    grep -v -e "^PLAY RECAP" -e " changed=0 " | awk '{ print $0 }' | sort | xargs -r | grep -q .; then
    local srv dest log
    for srv in ${srvs}; do
      info "  rsync ${srv}"
      dest="${srv}:/var/www/${site}"
      log="${logprefix}.${site}.rsync.${srv}.log"
      echo -e "\n# ${EPOCHSECONDS}\n# $(date -R)" >>${log}
      if ! rsync --verbose --recursive ~/tmp/hx/${site}/ ${dest} >>${log} 2>/dev/null; then
        info "    NOT ok" >&2
      fi
      info "  rsync ${srv} log"
      if ! rsync ${log} ${dest} &>/dev/null; then
        info "    NOT ok" >&2
      fi
    done
  fi
}

#######################################################################
set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..
source ./hx/hx-lib.sh

[[ -d ~/tmp/hx ]]
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP-info' INT QUIT TERM EXIT

info "pid $$"
pit_stop info 0
logprefix=~/tmp/hx/$(basename $0)

while :; do
  #--------------------------------------------------------------------
  site="site01"
  srvs=""
  tags="coredump,issue,trace"

  info "${site}  tags:  ${tags}"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags ${tags} -e '{ "infodir": "~/tmp/hx/'${site}'" }' \
    -e '{ "issue_since": "24 hours ago" }' -e '{ "trace_since": "24 hours ago" }' \
    &>${logprefix}.${site}.ansible.log; then
    info "  NOT ok" >&2
  fi
  sync_site ${site} ${srvs}
  pit_stop info

  #--------------------------------------------------------------------
  site="site02"
  srvs=""
  tags="artefact"

  info "${site}  tags:  ${tags}"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags ${tags} -e '{ "infodir": "~/tmp/hx/'${site}'" }' \
    &>${logprefix}.${site}.ansible.log; then
    info "  NOT ok" >&2
  fi
  sync_site ${site} ${srvs}
  pit_stop info

  #--------------------------------------------------------------------
  pit_stop info 300
done
