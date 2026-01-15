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
  info "healthy"
  ./site-info.yaml --limit 'hx:!hi' --tags artefact,issue,coredump,trace &>${log}.info.healthy.log || true

  if awk '/^PLAY RECAP/,/^$/' ${log}.info.log | grep -v -e "^PLAY RECAP" -e " changed=0 " | grep -q .; then
    info "rsync"
    # shellcheck disable=SC2043
    for dest in foo; do
      if ! rsync --compress --recursive --verbose \
        ~/tmp/tor-relays/{artefact,coredump,dmesg,issue.txt,kconfig,trace} ${dest}:/var/www/site01 \
        &>${log}.rsync.${dest}.log; then
        info "rsync ${dest} NOT ok"
      fi
    done
  fi

  info "sleep"
  sleep 300
done
