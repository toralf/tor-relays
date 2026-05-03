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
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP-IMAGE' INT QUIT TERM EXIT

info "pid $$"
pit_stop 0 STOP-IMG

while :; do
  while read -r f; do
    if [[ ! -f ${f}.image ]]; then
      cp ${f} ${f}.image

    elif ! diff -q ${f} ${f}.image >/dev/null; then
      i=$(cut -f 3 -d '.' -s <<<${f})
      cp ${f} ${f}.image

      info "image ${i}"
      if ! ./hx/hx-test.sh -e -t image -b ${i} &>${logprefix}.${i}.log; then
        info "  NOT ok" >&2
      fi
      info "image build ${i}"
      if ! ./hx/hx-test.sh -e -t image_build -b ${i} &>${logprefix}.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop 60 STOP-IMAGE
    fi
  done < <(
    find ~/tmp/hx/ -maxdepth 1 -type f -name 'git.kernel.*' |
      grep -v "\.image$" |
      shuf
  )

  pit_stop 300 STOP-IMAGE
done
