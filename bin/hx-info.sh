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
trap 'echo stopping...; touch /tmp/STOP' INT QUIT TERM EXIT

log=/tmp/$(basename $0)

while :; do
  info "check"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags artefact,issue,coredump,trace &>${log}.info.healthy.log; then
    info "  NOT ok"
  fi

  if awk '/^PLAY RECAP/,/^$/' ${log}.info.log | grep -v -e "^PLAY RECAP" -e " changed=0 " | grep -q .; then
    dest="foo"
    info "rsync to ${dest}"
    if ! rsync --compress --recursive --verbose \
      ~/tmp/tor-relays/{artefact,coredump,dmesg,issue.txt,kconfig,trace} ${dest}:/var/www/site01 \
      &>${log}.rsync.${dest}.log; then
      info "  NOT ok"
    fi
  fi

  pit_stop 300
done
