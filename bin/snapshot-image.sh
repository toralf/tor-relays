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
parameter=""                                   # e.g. --tags
setup="create"

while getopts a:b:p:r opt; do
  case $opt in
  a) arch="${OPTARG}" ;;
  b) branch="${OPTARG}" ;;
  p) parameter="${OPTARG}" ;;
  r) setup="rebuild" ;;
  *)
    echo " unknown parameter '${opt}'" >&2
    exit 1
    ;;
  esac
done

names_debian=$(eval echo hid-${arch}-${branch}-{,no}bp-{,no}cl)
names_ubuntu=$(eval echo hiu-${arch}-${branch})

names=$(xargs <<<"${names_debian} ${names_ubuntu}")

cd $(dirname $0)/..

# snapshots are bound to region
export HCLOUD_LOCATION="hel1"

./bin/${setup}-server.sh ${names}
./site-snapshot.yaml --limit $(xargs <<<"${names} localhost" | tr ' ' ',') ${parameter}
./bin/delete-server.sh ${names}
