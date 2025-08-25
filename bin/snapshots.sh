#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# create/update snaphot images

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin
source $(dirname $0)/lib.sh

# snapshots are bound to region
export HCLOUD_LOCATION="hel1"

setProject
[[ ${project} == "test" ]]

arch="{amd,arm,intel}"
branch="{lts,ltsrc,stable,stablerc,master}" # mapped to a git commit-ish in ./inventory
names=""                                    # this option rules over options "arch" and "branch"
os="t u"                                    # e.g. (d)ebian bookworm, debian (t)rixie, (u)buntu

while getopts a:b:n:o: opt; do
  case ${opt} in
  a) arch="${OPTARG}" ;;
  b) branch="${OPTARG}" ;;
  n) names="${OPTARG}" ;;
  o) os="${OPTARG}" ;;
  *)
    echo " unknown parameter '${opt}'" >&2
    exit 1
    ;;
  esac
done

if [[ -z ${names} ]]; then
  names=$(
    for i in ${os}; do
      case ${i} in
      d | t) eval echo hi-${i}-${arch}-${branch}-{,no}bp-{,no}cl ;;
      u) eval echo hi-u-${arch}-${branch} ;;
      *)
        echo " os parameter value ${i} is not implemented" >&2
        exit 1
        ;;
      esac
    done
  )
fi

cd $(dirname $0)/..

trap 'echo "  ^^    systems:    ${names}"' INT QUIT TERM EXIT

./bin/create-server.sh ${names}
./site-snapshot.yaml --limit $(xargs <<<"${names} localhost" | tr ' ' ',')
./bin/delete-server.sh ${names} 2>/dev/null

trap - INT QUIT TERM EXIT
