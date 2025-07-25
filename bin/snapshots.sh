#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# create/update snaphot images

function generate_names() {
  xargs -n 1 <<<$* |
    while read -r os; do
      case ${os} in
      d) eval echo hi-${os}-${arch}-${branch}-{,no}bp-{,no}cl ;;
      u) eval echo hi-${os}-${arch}-${branch} ;;
      *) exit 1 ;;
      esac
    done
}

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin
source $(dirname $0)/lib.sh

# snapshots are bound to region
export HCLOUD_LOCATION="hel1"
export ANSIBLE_DISPLAY_OK_HOSTS=false

setProject
[[ ${project} == "test" ]]

arch="{amd,arm,intel}"
branch="{lts,ltsrc,stable,stablerc,master}" # mapped in inventory to a git commit-ish
names=""                                    # option exclusive to "arch" and "branch"
os="d u"                                    # operating system, (d)ebian, (u)buntu
parameter=""                                # e.g. -p '-e git_clone_from_scratch=true'

while getopts a:b:n:o:p:s opt; do
  case ${opt} in
  a) arch="${OPTARG}" ;;
  b) branch="${OPTARG}" ;;
  n) names="${OPTARG}" ;;
  o) os="${OPTARG}" ;;
  p) parameter="${OPTARG}" ;;
  s) names=$(hcloud --quiet image list --type snapshot --output noheader --output columns=description | xargs -r -n 1 printf "hi-%s ") ;;
  *)
    echo " unknown parameter '${opt}'" >&2
    exit 1
    ;;
  esac
done

if [[ -z ${names} ]]; then
  names=$(xargs <<<"$(generate_names ${os})")
fi

cd $(dirname $0)/..

trap 'echo "  ^^  systems:    ${names}"' INT QUIT TERM EXIT

./bin/create-server.sh ${names}
./site-snapshot.yaml --limit $(xargs <<<"${names} localhost" | tr ' ' ',') ${parameter}
./bin/delete-server.sh ${names} 2>/dev/null

trap - INT QUIT TERM EXIT
