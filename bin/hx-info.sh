#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

set -euf
set -m
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..
source ./bin/hx-lib.sh

if [[ ! -d ~/tmp/hx ]]; then
  mkdir -p ~/tmp/hx
fi
logprefix=~/tmp/hx/$(basename $0)
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP-INFO' INT QUIT TERM EXIT

info "pid $$"
pit_stop 0 STOP-INFO
while :; do

  #--------------------------------------------------------------------
  i="info01"

  info "${i}"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags artefact,coredump,issue,trace -e '{ "infodir": "~/tmp/hx/'${i}'" }' \
    -e '{ "issue_since": "1 days ago" }' -e '{ "trace_since": "1 days ago" }' &>${logprefix}.${i}.log; then
    info "  NOT ok" >&2
  fi

  if awk '/^PLAY RECAP/,/^$/' ${logprefix}.${i}.log |
    grep -v -e "^PLAY RECAP" -e " changed=0 " | awk '{ print $0 }' | sort | xargs -r | grep -q .; then
    echo -e "${EPOCHSECONDS}\n$(date -R)" >~/tmp/hx/${i}/last-change.txt
    for dest in foo bar; do
      info "  rsync ${i} to ${dest}"
      # trailing / in "from" is intentionally
      if ! rsync --verbose --recursive ~/tmp/hx/${i}/ ${dest}:/var/www/site01 &>${logprefix}.${i}.rsync.log; then
        info "  NOT ok" >&2
      fi
    done
  fi

  #--------------------------------------------------------------------
  pit_stop 300 STOP-INFO
done
