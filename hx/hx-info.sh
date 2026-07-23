#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

function sync_site() {
  local srv dest log

  if awk '/^PLAY RECAP/,/^$/' ${logprefix}.${site}.ansible.${tags}.log |
    grep -v -e "^PLAY RECAP" -e " changed=0 " | awk '{ print $0 }' | sort | xargs -r | grep -q .; then
    for srv in $*; do
      info "  rsync ${site} to ${srv}"
      dest="${srv}:/var/www/${site}"
      log="${logprefix}.${site}.rsync.${srv}.log"
      echo -e "\n# epoch ${EPOCHSECONDS}\n# $(date -R)" >>${log}
      if ! rsync --verbose --recursive ~/tmp/hx/${site}/ ${dest} >>${log} 2>/dev/null; then
        info "  NOT ok" >&2
      else
        info "  rsync ${site} log to ${srv}"
        if ! rsync --verbose ${log} ${dest} &>/dev/null; then
          info "  NOT ok" >&2
        fi
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
logprefix=~/tmp/hx/$(basename $0)
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP-info' INT QUIT TERM EXIT

info "pid $$"
pit_stop info 0

while :; do
  #--------------------------------------------------------------------
  site="site01"
  tags="coredump,issue,trace"
  srvs=""

  info "${site} ${tags}"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags ${tags} -e '{ "infodir": "~/tmp/hx/'${site}'" }' \
    -e '{ "issue_since": "24 hours ago" }' -e '{ "trace_since": "24 hours ago" }' \
    &>${logprefix}.${site}.ansible.${tags}.log; then
    info "  NOT ok" >&2
  fi
  sync_site $(eval echo ${srvs})
  pit_stop info

  #--------------------------------------------------------------------
  site="site02"
  tags="artefact"
  srvs=""

  info "${site} ${tags}"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags ${tags} -e '{ "infodir": "~/tmp/hx/'${site}'" }' \
    &>${logprefix}.${site}.ansible.${tags}.log; then
    info "  NOT ok" >&2
  fi
  sync_site $(eval echo ${srvs})
  pit_stop info

  #--------------------------------------------------------------------
  pit_stop info 300
done
