#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# build + deploy tests

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..

[[ ${1-} == "-t" && $# -ge 2 ]]

while getopts a:b:t: opt; do
  case ${opt} in
  a) arch=${OPTARG} ;;
  b) branch=${OPTARG} ;;
  t)
    type=${OPTARG}
    case ${type} in
    app)
      arch='{amd,arm}'
      branch='{ltsrc,master}'
      ;;
    kernel)
      arch='{amd,arm,intel}'
      branch='{ltsrc,master,stablerc}'
      ;;
    image)
      arch='{arm,x86}'
      branch='{ltsrc,master,stablerc}'
      ;;
    *)
      echo "unknown type ${type}" >&2
      exit 1
      ;;
    esac
    ;;
  *)
    echo "unknown opt ${opt}" >&2
    exit 1
    ;;
  esac
done

trap 'echo "  ^^    systems:    ${names}"' INT QUIT TERM EXIT

if [[ ${type} == "app" ]]; then
  names=$(eval echo h{n,s,t}a-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-42 h{n,s,t}a-un-${arch}-${branch}-x-x-42)
  time ./bin/create-server.sh ${names}
  time ./site-test.yaml --limit "h?a-*-42" --skip-tags shutdown,snapshot

elif [[ ${type} == "image" ]]; then
  names=$(eval echo hi-{db,dt,un}-${arch}-${branch})
  time ./bin/create-server.sh ${names}
  time ./site-test.yaml --limit "hi-*" --skip-tags autoupdate,kernel-src
  # remove superseeded snapshots
  hcloud --quiet image list --type snapshot --output noheader --output columns=id,description |
    sort -r |
    awk 'x[$2]++ { print $1 }' |
    xargs -r hcloud --poll-interval 5s image delete 1>/dev/null

elif [[ ${type} == "kernel" ]]; then
  names=$(eval echo hik-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-42 hik-un-${arch}-${branch}-x-x-42)
  time ./bin/create-server.sh ${names}
  time ./site-test.yaml --limit "hik-*-42" --skip-tags autoupdate,shutdown,snapshot

else
  echo "unknown type ${type}" >&2
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
