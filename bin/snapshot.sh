#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# create/update snaphot images

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..
source ./bin/lib.sh

# snapshots are bound to region
export HCLOUD_LOCATION="hel1"

setProject
[[ ${project} == "test" ]]

arch="{arm,x86}"                 # e.g. -a "{amd,arm,intel}"
branch="{ltsrc,master,stablerc}" # mapped to a git commit-ish in ./inventory
names=""                         # set image names explicitly
os="{db,dt,un}"                  # debian bookworm + trixie, ubuntu noble

# default: do only update the Git repo
play_args="-e delete_instance_afterwards=true -e kernel_git_build=no"

while getopts a:b:n:o:p: opt; do
  case ${opt} in
  a) arch="${OPTARG}" ;;
  b) branch="${OPTARG}" ;;
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

trap 'echo "  ^^    systems:    ${names}"' INT QUIT TERM EXIT

./bin/create-server.sh ${names}
./site-snapshot.yaml --limit $(xargs <<<"${names} localhost" | tr ' ' ',') ${play_args}
./bin/delete-server.sh ${names} 2>/dev/null

trap - INT QUIT TERM EXIT
