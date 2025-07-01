#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# create/update snaphot images

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

project=$(hcloud context active)
echo -e "\n >>> using Hetzner project ${project:?}"

arch="{amd,arm,intel}"
branch="{lts,ltsrc,stable,stablerc,master}" # mapped in inventory to a git commit-ish
names=""                                    # option exclusive to "arch" and "branch"
parameter=""                                # e.g. "--tags ..."

while getopts a:b:en:p: opt; do
  case ${opt} in
  a) arch="${OPTARG}" ;;
  b) branch="${OPTARG}" ;;
  e) names=$(hcloud image list --type snapshot --output noheader --output columns=description | xargs -r -n 1 printf "hi%s ") ;;
  n) names="${OPTARG}" ;;
  p) parameter="${OPTARG}" ;;
  *)
    echo " unknown parameter '${opt}'" >&2
    exit 1
    ;;
  esac
done

if [[ -z ${names} ]]; then
  names_debian=$(eval echo hid-${arch}-${branch}-{,no}bp-{,no}cl)
  names_ubuntu=$(eval echo hiu-${arch}-${branch})

  names=$(xargs <<<"${names_debian} ${names_ubuntu}")
fi

cd $(dirname $0)/..

# snapshots are bound to region
export HCLOUD_LOCATION="hel1"
export ANSIBLE_DISPLAY_OK_HOSTS=false

./bin/create-server.sh ${names}
cmd=""
if ! ./site-snapshot.yaml --limit \'$(xargs <<<"${names} localhost" | tr ' ' ',')\' ${parameter}; then
  cmd='echo run this:      '
fi
${cmd} ./bin/delete-server.sh ${names} 2>/dev/null
