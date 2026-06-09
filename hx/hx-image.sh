#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..
source ./hx/hx-lib.sh

[[ -d ~/tmp/hx ]]
logprefix=~/tmp/hx/$(basename $0)
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP-image' INT QUIT TERM EXIT

info "pid $$"
pit_stop image 0

while :; do
  while read -r f; do
    # set HEAD
    if [[ ! -f ${f}.image ]]; then
      cp ${f} ${f}.image

    # new HEAD
    elif ! diff -q ${f} ${f}.image >/dev/null; then
      repo=$(cut -f 3 -d '.' -s <<<${f})
      info "image ${repo}"
      cp ${f} ${f}.image
      if ! ./hx/hx-test.sh -e -t image -b ${repo} -a '{arm,x86}' &>${logprefix}.${repo}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop image
    fi
  done < <(
    find ~/tmp/hx/ -maxdepth 1 -type f -name 'git.kernel.*' |
      grep -v "\.image$" |
      grep -E "${1:-.}" |
      shuf
  )

  pit_stop image 300
done
