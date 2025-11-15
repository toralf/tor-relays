#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# build + deploy tests

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..

[[ ${1-} == "-t" && $# -ge 2 ]]

number=42
while getopts a:b:n:t: opt; do
  case ${opt} in
  a) arch=${OPTARG} ;;
  b) branch=${OPTARG} ;;
  n) number=${OPTARG} ;;
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
  names=$(eval echo h{n,s,t}a-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-${number} h{n,s,t}a-un-${arch}-${branch}-x-x-${number})
  time ./bin/create-server.sh ${names}
  time ./site-test-app.yaml --limit "$(xargs <<<${names} | tr ' ' ',')" --skip-tags shutdown,snapshot -e 'kernel_git_build="background"'

elif [[ ${type} == "image" ]]; then
  names=$(eval echo hi-{db,dt,un}-${arch}-${branch})
  time ./bin/create-server.sh ${names}
  time ./site-test.yaml --limit "$(xargs <<<${names} | tr ' ' ',')" --skip-tags autoupdate,kernel-build
  # remove superseeded snapshots
  hcloud --quiet image list --type snapshot --output noheader --output columns=id,description |
    sort -r |
    awk 'x[$2]++ { print $1 }' |
    xargs -r hcloud --poll-interval 5s image delete >/dev/null

elif [[ ${type} == "kernel" ]]; then
  names=$(eval echo hik-{db,dt}-${arch}-${branch}-{,no}bp-{,no}cl-${number} hik-un-${arch}-${branch}-x-x-${number})
  time ./bin/create-server.sh ${names}
  time ./site-test.yaml --limit "$(xargs <<<${names} | tr ' ' ',')" --skip-tags autoupdate,shutdown,snapshot

else
  echo "unknown type ${type}" >&2
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
