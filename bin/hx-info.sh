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

if [[ ! -d ~/hx ]]; then
  mkdir ~/hx
fi
log=~/hx/$(basename $0)

while :; do
  info "healthy"
  if ! ./site-info.yaml --limit 'hx,!hix' --tags artefact,issue,coredump,trace &>${log}.info.healthy.log; then
    info "  NOT ok" >&2
  fi

  if awk '/^PLAY RECAP/,/^$/' ${log}.info.healthy.log | grep -v -e "^PLAY RECAP" -e " changed=0 " | grep .; then
    # have a local full backup
    info "rsync to ~/site01"
    if ! rsync --recursive ~/tmp/tor-relays/{artefact,coredump,dmesg,issue.txt,kconfig,trace} ~/site01 &>/dev/null; then
      info "  NOT ok" >&2
    fi
    # rsync to web site/s
    for dest in foo bar; do
      info "rsync to remote ${dest}"
      if ! rsync --recursive ~/site01 ${dest}:/var/www/site01 &>/dev/null; then
        info "  NOT ok" >&2
      fi
    done
  fi

  pit_stop 300
done
