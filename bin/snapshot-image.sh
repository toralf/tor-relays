#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# create/update snaphot images

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

# default: 3 x 6 variants
arch="{amd,arm,intel}"
branch="{dist,lts,ltsrc,stable,stablerc,main}" # mapped in the inventory to a git commit-ish
parameters=""                                  # e.g. --tags
setup="create"

while getopts a:b:p:r opt; do
  case $opt in
  a) arch="${OPTARG}" ;;
  b) branch="${OPTARG}" ;;
  p) parameters="${OPTARG}" ;;
  r) setup="rebuild" ;;
  *)
    echo " unknown parameter '${opt}'" >&2
    exit 1
    ;;
  esac
done

systems_debian=$(eval echo hid-${arch}-${branch}-{,no}bp-{,no}cl)
systems_ubuntu=$(eval echo hiu-${arch}-${branch})

cd $(dirname $0)/..

# snapshots are bound to a region
export HCLOUD_LOCATION=hel1

if [[ ${setup} == "create" ]]; then
  ./bin/create-server.sh ${systems_debian}
  HCLOUD_FALLBACK_IMAGE="ubuntu-24.04" ./bin/create-server.sh ${systems_ubuntu}
else
  ./bin/rebuild-server.sh ${systems_debian} ${systems_ubuntu}
fi
./site-snapshot.yaml --limit $(tr ' ' ',' <<<${systems_debian},${systems_ubuntu}),localhost ${parameters}
