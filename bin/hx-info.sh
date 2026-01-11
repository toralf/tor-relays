#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

function info() {
  echo -e " $(date) $*                            "
}

#######################################################################
set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..

log=/tmp/$(basename $0)

while :; do
  info "info"
  ./site-info.yaml --limit 'hx:!hi' --tags artefact,issue,coredump,trace &>${log}.info.log || true

  if awk '/^PLAY RECAP/,/^$/' ${log}.info.log | grep -v -e "^PLAY RECAP" -e " changed=0 " | grep -q .; then
    info "rsync"
    (
      cd ~/tmp/tor-relays
      for web in foo bar baz; do
        if : rsync --compress --recursive artefact coredump dmesg issue.txt kconfig trace ${web}://var/www/html &>${log}.rsync.${web}.log; then
          info "rsync ${web} ok"
        else
          info "rsync ${web} NOT ok"
        fi
      done
    )
  fi

  info "sleep"
  sleep 300
done
