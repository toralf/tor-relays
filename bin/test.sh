#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# build + deploy tests

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..

[[ ${1-} == "-t" && $# -ge 2 ]]

arch='{arm,x86}'
branch='{ltsrc,mainline,stablerc}'
uid=$(printf "%02i" $((RANDOM % 100)))

while getopts a:b:t:u: opt; do
  case ${opt} in
  a) arch=${OPTARG} ;;
  b) branch=${OPTARG} ;;
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
  names=$(eval echo h{m,p,s}-dt-${arch}-${branch}-{,no}bp-{,no}cl-${uid} h{m,p,s}-un-${arch}-${branch}-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-app.yaml --limit "$(tr ' ' ',' <<<${names})"

elif [[ ${type} =~ "image" ]]; then
  if [[ ${type} == "image_build" ]]; then
    # build kernel
    names=$(eval echo hi-dt-${arch}-${branch}-{,no}bp-{,no}cl-${uid} hi-un-${arch}-${branch}-x-x-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "$(tr ' ' ',' <<<${names})"
  else
    # clone kernel repo only
    names=$(eval echo hi-{dt,un}-${arch}-${branch}-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "$(tr ' ' ',' <<<${names})" --skip-tags kernel-build
  fi

  # remove superseeded snapshots (== same description, old id)
  hcloud --quiet image list --type snapshot --output noheader --output columns=id,description |
    sort -r |
    awk 'x[$2]++ { print $1 }' |
    xargs -r hcloud --poll-interval 5s image delete >/dev/null

elif [[ ${type} == "kernel" ]]; then
  names=$(eval echo hi-dt-${arch}-${branch}-{,no}bp-{,no}cl-${uid} hi-un-${arch}-${branch}-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-kernel.yaml --limit "$(tr ' ' ',' <<<${names})"

else
  echo "unknown type ${type}" >&2
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
