#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: create golden images, test etc.

function printNames() {
  for o in $(eval echo ${os}); do
    if [[ $o =~ ^d ]]; then
      eval echo hi-${o}-${arch}-${branch}-bp-cl-${fw}-${mod}-${uid}
    fi
    if [[ $o =~ ^u ]]; then
      eval echo hi-${o}-${arch}-${branch}-x-x-${fw}-${mod}-${uid}
    fi
  done |
    xargs
}

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

export RETRY_FILES_ENABLED="True"
export RETRY_FILES_SAVE_PATH="/tmp"

cd $(dirname $0)/..

[[ $# -ge 2 ]]

uid=$(printf "%07i" $$)
while getopts a:b:ef:m:o:t:u: opt; do
  case ${opt} in
  a) arch=${OPTARG} ;;
  b) branch=${OPTARG} ;; # '{lr,lt,ml,sr,st}'
  e) set +e ;;           # created systems will be always deleted
  f) fw=${OPTARG} ;;
  o) os=${OPTARG} ;;
  m) mod=${OPTARG} ;;
  t) task=${OPTARG} ;;
  u) uid=${OPTARG} ;;
  *)
    echo "unknown opt ${opt}" >&2
    exit 1
    ;;
  esac
done

trap 'echo "  ^^    systems:    ${names}" >&2' INT QUIT TERM EXIT

arch=${arch:-'{arm,x86}'}
fw=${fw:-'{ipt,nft}'}
mod=${mod:-'{mod,non}'}
os=${os:-'{d13,u26}'}

if [[ ${task} == "bin" ]]; then
  names=$(eval echo h{b,m,p,r,s}-${os}-${arch}-di-x-x-${fw}-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-setup.yaml --limit "h?-*-${uid}"

elif [[ ${task} == "image" ]]; then
  branch=${branch:-'{lr,ml,sr}'}
  names=$(eval echo hi-${os}-${arch}-${branch}-x-x-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-image.yaml --limit "h?-*-${uid}" -e '{ "kernel_build": false }'
  ./bin/clean-snapshots.sh

elif [[ ${task} == "kernel" ]]; then
  branch=${branch:-'{lr,ml,sr}'}
  names=$(printNames)
  time ./bin/create-server.sh ${names}
  time ./site-test-kernel.yaml --limit "h?-*-${uid}" -e '{ "kernel_build": true }'

elif [[ ${task} == "setup" ]]; then
  branch=${branch:-'di'}
  names=$(printNames)
  time ./bin/create-server.sh ${names}
  time ./site-test-setup.yaml --limit "h?-*-${uid}"

else
  echo "unknown task ${task}" >&2
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
