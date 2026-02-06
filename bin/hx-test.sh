#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: maintain golden image and test apps

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

export RETRY_FILES_ENABLED="True"
export RETRY_FILES_SAVE_PATH="/tmp"

cd $(dirname $0)/..

[[ ${1-} == "-t" && $# -ge 2 ]]

arch='{arm,x86}'
extra=''
os='{db,dt,un}'
uid=$(printf "%06i" $$)
while getopts a:b:o:t:u:x: opt; do
  case ${opt} in
  a) arch=${OPTARG} ;;
  b) branch=${OPTARG} ;;
  o) os=${OPTARG} ;;
  t) type=${OPTARG} ;;
  u) uid=${OPTARG} ;;
  x) extra=${OPTARG} ;;
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
  time ./site-test-setup.yaml --limit "h[bmprs]-*-*-*-*-*-${uid}" ${extra}

elif [[ ${type} == "full" ]]; then
  branch=${branch:-'{dist,ltsrc,mainline,stablerc}'}
  names=$(eval echo h{b,m,p,r,s}-${os}-${arch}-${branch}-x-x-${uid} | xargs -n 1 | shuf | xargs)
  time ./bin/create-server.sh ${names}
  time ./site-test-setup.yaml --limit "h[bmprs]-*-*-*-*-*-${uid}" ${extra}

elif [[ ${type} =~ "image" ]]; then
  branch=${branch:-'{ltsrc,mainline,stablerc}'}
  if [[ ${type} == "image_build" ]]; then
    # clone kernel repo + build it
    names=$(eval echo hi-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-${uid} hi-un-${arch}-${branch}-x-x-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "hi-*-*-*-*-*-${uid}" ${extra} --skip-tags nginx-config,nginx-openssl
  else
    # only clone kernel repo
    names=$(eval echo hi-${os}-${arch}-${branch}-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "hi-*-*-*-${uid}" ${extra} --skip-tags nginx-config,nginx-openssl,kernel-make
  fi

elif [[ ${type} == "kernel" ]]; then
  branch=${branch:-'{ltsrc,mainline,stablerc}'}
  names=$(eval echo hi-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-${uid} hi-un-${arch}-${branch}-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-kernel.yaml --limit "hi-*-*-*-*-*-${uid}" ${extra}

else
  echo "unknown type ${type}" >&2
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
