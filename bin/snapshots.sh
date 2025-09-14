#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# create/update snaphot images

function allFlavours() {
  for i in $(eval echo ${os}); do
    case ${i} in
    db | dt) eval echo hi-${i}-${arch}-${branch}-{,no}bp-{,no}cl ;;
    un) eval echo hi-${i}-${arch}-${branch} ;;
    esac
  done |
    xargs
}

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin
source $(dirname $0)/lib.sh

# snapshots are bound to region
export HCLOUD_LOCATION="hel1"

setProject
[[ ${project} == "test" ]]

arch="{x86,arm}"
branch="{lts,ltsrc,stable,stablerc,master}" # mapped to a git commit-ish in ./inventory
names=""                                    # directly set image names
os="{db,dt,un}"                             # debian bookworm, debian trixie, ubuntu noble
snapshot_parameters=""

while getopts a:b:fn:o: opt; do
  case ${opt} in
  a) arch="${OPTARG}" ;;
  b) branch="${OPTARG}" ;;
  f)
    arch="{amd,intel,arm}"
    snapshot_parameters='-e kernel_vanilla_build=yes'
    names=$(allFlavours)
    ;;
  n) names="${OPTARG}" ;;
  o) os="${OPTARG}" ;;
  *)
    echo " unknown parameter '${opt}'" >&2
    exit 1
    ;;
  esac
done

if [[ -z ${names} ]]; then
  names=$(eval echo hi-${os}-${arch}-${branch})
fi

cd $(dirname $0)/..

trap 'echo "  ^^    systems:    ${names}"' INT QUIT TERM EXIT

./bin/create-server.sh ${names}
./site-snapshot.yaml --limit $(xargs <<<"${names} localhost" | tr ' ' ',') ${snapshot_parameters}
./bin/delete-server.sh ${names} 2>/dev/null

trap - INT QUIT TERM EXIT
