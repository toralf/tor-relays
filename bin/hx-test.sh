#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goals:
#   - test
#   - create golden image

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

export RETRY_FILES_ENABLED="True"
export RETRY_FILES_SAVE_PATH="/tmp"

cd $(dirname $0)/..

[[ ${1-} == "-t" && $# -ge 2 ]]

arch='{arm,x86}'
os='{db,dt,un}'
uid=$$

while getopts a:b:o:t:u: opt; do
  case ${opt} in
  a) arch=${OPTARG} ;;
  b) branch=${OPTARG} ;;
  o) os=${OPTARG} ;;
  t) type=${OPTARG} ;;
  u) uid=${OPTARG} ;;
  *)
    echo "unknown opt ${opt}" >&2
    exit 1
    ;;
  esac
done

trap 'echo "  ^^    systems:    ${names}"' INT QUIT TERM EXIT

if [[ ${type} == "app" ]]; then
  names=$(eval echo h{b,m,p,r,s}-${os}-${arch}-dist-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-setup.yaml --limit "$(tr ' ' ',' <<<${names})"

elif [[ ${type} == "full" ]]; then
  branch=${branch:-'{dist,ltsrc,mainline,stablerc}'}
  names=$(eval echo h{b,m,p,r,s}-${os}-${arch}-${branch}-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-setup.yaml --limit "$(tr ' ' ',' <<<${names})"

elif [[ ${type} =~ "image" ]]; then
  branch=${branch:-'{ltsrc,mainline,stablerc}'}
  if [[ ${type} == "image_build" ]]; then
    # clone + build kernel
    names=$(eval echo hi-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-${uid} hi-un-${arch}-${branch}-x-x-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "$(tr ' ' ',' <<<${names})"
  else
    # clone kernel
    names=$(eval echo hi-${os}-${arch}-${branch}-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "$(tr ' ' ',' <<<${names})" --skip-tags kernel-make
  fi

elif [[ ${type} == "kernel" ]]; then
  branch=${branch:-'{ltsrc,mainline,stablerc}'}
  names=$(eval echo hi-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-${uid} hi-un-${arch}-${branch}-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-kernel.yaml --limit "$(tr ' ' ',' <<<${names})"

else
  echo "unknown type ${type}" >&2
  exit 1
fi

if [[ ${type} != "image_build" ]]; then
  time ./bin/delete-server.sh ${names}
fi

trap - INT QUIT TERM EXIT
