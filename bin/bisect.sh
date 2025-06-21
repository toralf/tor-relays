#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# bisect codes: 0 (good), 1 (bad), 125 (untestable), >127 (bail out)

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

if ! name=${1:?}; then
  exit 255
fi

cd $(dirname $0)/..

if ! ping -q -c 3 ${name} 1>/dev/null; then
  ./bin/rebuild-server.sh ${name} || exit 255
fi

bisect_id=$(cat ~/devel/linux/.git/BISECT_HEAD) || exit 254

# deploy w/o kernel build
./site.yaml --limit ${name} --skip-tags kernel-src,auto-update || exit 253

# bisect test
./site.yaml --limit ${name} -e kernel_git_version=${bisect_id} --tags kernel-src --skip-tags auto-update
