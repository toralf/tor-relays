#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# create/update snaphot images -or- test kernel versions

# Debian has 4 different dist kernels
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

arch="{arm,x86}"                 # e.g. -a "{amd,arm,intel}"
branch="{ltsrc,master,stablerc}" # mapped to a git commit-ish in ./inventory
names=""                         # set image names explicitly
os="{db,dt,un}"                  # debian bookworm + trixie, ubuntu noble

# test of recent kernels: -a "{amd,arm,intel}" -p "-e delete_instance_afterwards=true --skip-tags snapshot"
# default: do only update the Git repo of snapshots
play_args="-e delete_instance_afterwards=true -e kernel_git_build=no"

while getopts a:b:fn:o:p: opt; do
  case ${opt} in
  a) arch="${OPTARG}" ;;
  b) branch="${OPTARG}" ;;
  f) names=$(allFlavours) ;;
  n) names="${OPTARG}" ;;
  o) os="${OPTARG}" ;;
  p) play_args="${OPTARG}" ;;
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
./site-snapshot.yaml --limit $(xargs <<<"${names} localhost" | tr ' ' ',') ${play_args}
./bin/delete-server.sh ${names} 2>/dev/null

trap - INT QUIT TERM EXIT
