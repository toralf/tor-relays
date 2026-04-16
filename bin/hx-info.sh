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

trap 'echo; echo stopping...; touch /tmp/STOP' INT QUIT TERM EXIT
if [[ ! -d ~/hx ]]; then
  mkdir ~/hx
fi
logprefix=~/hx/$(basename $0)

while :; do
  pit_stop 1

  #--------------------------------------------------------------------
  i="info01"

  info "$i"
  if ! ./site-info.yaml --limit 'hx' --tags artefact,coredump,issue,trace \
    -e '{ "infodir": "~/'$i'" }' -e '{ "issue_since": "1 days ago" }' -e '{ "trace_since": "1 days ago" }' &>${logprefix}.${i}.log; then
    info "  NOT ok" >&2
  fi

  if awk '/^PLAY RECAP/,/^$/' ${logprefix}.${i}.log | grep -v -e "^PLAY RECAP" -e " changed=0 " | grep .; then
    for dest in foo bar; do
      info "  rsync $i to ${dest}"
      if ! rsync --recursive ~/$i/ ${dest}:/var/www/site01 &>${logprefix}.${i}.rsync.log; then
        info "  NOT ok" >&2
      fi
    done
  fi

  #--------------------------------------------------------------------
  pit_stop 300
done
