#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goals:
#   - test
#   - create golden image

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..

[[ ${1-} == "-t" && $# -ge 2 ]]

arch='{arm,x86}'
uid=$$

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
  names=$(eval echo h{b,m,p,r,s}-{dt,un}-${arch}-dist-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-setup.yaml --limit "$(tr ' ' ',' <<<${names})"

elif [[ ${type} == "full" ]]; then
  branch=${branch:-'{dist,ltsrc,mainline,stablerc}'}
  names=$(eval echo h{b,m,p,r,s}-{dt,un}-${arch}-${branch}-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-setup.yaml --limit "$(tr ' ' ',' <<<${names})"

elif [[ ${type} =~ "image" ]]; then
  branch=${branch:-'{ltsrc,mainline,stablerc}'}
  if [[ ${type} == "image_build" ]]; then
    # clone + build kernel
    names=$(eval echo hi-dt-${arch}-${branch}-{,no}bp-{,no}cl-${uid} hi-un-${arch}-${branch}-x-x-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "$(tr ' ' ',' <<<${names})"
  else
    # clone kernel
    names=$(eval echo hi-{dt,un}-${arch}-${branch}-${uid})
    time ./bin/create-server.sh ${names}
    time ./site-test-image.yaml --limit "$(tr ' ' ',' <<<${names})" --skip-tags kernel-make
  fi

  # remove superseeded snapshots (based on same description)
  hcloud --quiet image list --type snapshot --output noheader --output columns=id,description |
    sort -r |
    awk 'x[$2]++ { print $1 }' |
    xargs -r hcloud --poll-interval 5s image delete >/dev/null

elif [[ ${type} == "kernel" ]]; then
  branch=${branch:-'{ltsrc,mainline,stablerc}'}
  names=$(eval echo hi-d{b,t}-${arch}-${branch}-{,no}bp-{,no}cl-${uid} hi-un-${arch}-${branch}-x-x-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-image.yaml --limit "$(tr ' ' ',' <<<${names})" --skip-tags shutdown,snapshot

else
  echo "unknown type ${type}" >&2
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
