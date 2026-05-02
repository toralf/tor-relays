#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

#######################################################################
set -euf
set -m
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..
source ./hx/hx-lib.sh

[[ -d ~/tmp/hx ]]
logprefix=~/tmp/hx/$(basename $0)
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP-IMG' INT QUIT TERM EXIT

info "pid $$"
pit_stop 0 STOP-IMG

while :; do
  ls ~/tmp/hx/git.kernel.* 2>/dev/null |
    grep -v "\.image$" |
    shuf |
    while read -r f; do
      if [[ ! -f ${f}.image ]]; then
        touch ${f}.image
      elif [[ ${f} -nt ${f}.image ]]; then
        i=$(cut -f 3 -d '.' -s <<<${f})
        info "image build for ${i}"
        touch ${f}.image
        if ! ./hx/hx-test.sh -e -t image_build -b ${i} &>${logprefix}.${i}.log; then
          info "  NOT ok" >&2
        fi
        pit_stop 60 STOP-IMG
      fi
    done

  pit_stop 300 STOP-IMG
done
