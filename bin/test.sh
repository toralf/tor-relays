#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# build + deploy tests

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..

[[ ${1-} == "-t" && $# -ge 2 ]]

uid=42
while getopts a:b:t:u: opt; do
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
      branch='{lts,ltsrc,master,stable,stablerc}'
      ;;
    *)
      echo "unknown type ${type}" >&2
      exit 1
      ;;
    esac
    ;;
  u) uid=${OPTARG} ;;
  *)
    echo "unknown opt ${opt}" >&2
    exit 1
    ;;
  esac
done

trap 'echo "  ^^    systems:    ${names}"' INT QUIT TERM EXIT

if [[ ${type} == "app" ]]; then
  names=$(eval echo h{m,s,t}-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-nowt-${uid} h{m,s,t}-un-${arch}-${branch}-x-x-nowt-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-app.yaml --limit "$(tr ' ' ',' <<<${names})"
  echo " rc=$?"

elif [[ ${type} == "image" ]]; then
  names=$(eval echo hi-{db,dt,un}-${arch}-${branch})
  time ./bin/create-server.sh ${names}
  time ./site-test-image.yaml --limit "$(tr ' ' ',' <<<${names})" --skip-tags kernel-build
  echo " rc=$?"
  # remove superseeded snapshots
  hcloud --quiet image list --type snapshot --output noheader --output columns=id,description |
    sort -r |
    awk 'x[$2]++ { print $1 }' |
    xargs -r hcloud --poll-interval 5s image delete >/dev/null

elif [[ ${type} == "kernel" ]]; then
  names=$(eval echo hi-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-wt-${uid} hi-un-${arch}-${branch}-x-x-wt-${uid})
  time ./bin/create-server.sh ${names}
  time ./site-test-kernel.yaml --limit "$(tr ' ' ',' <<<${names})"
  echo " rc=$?"

else
  echo "unknown type ${type}" >&2
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
