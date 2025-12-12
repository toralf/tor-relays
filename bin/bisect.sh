#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# bisect codes: 0 (good), 1 (bad), 125 (untestable), >127 (bail out)

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

if [[ $# -ne 1 ]]; then
  exit 255
fi

# target system
name=${1}

# maybe dead from previous run
if ! ping -q -c 3 ${name} >/dev/null; then
  $(dirname $0)/bin/rebuild-server.sh ${name} || exit 255
  $(dirname $0)/site-test-kernel.yaml --limit ${name} --skip-tags kernel-build,delete
fi

# we're called from "git bisect run" which was started in a local kernel git repo
bisect_id=$(<.git/BISECT_HEAD) || exit 254

# bisect: test kernel build + reboot
$(dirname $0)/site-test-kernel.yaml --limit ${name} -e kernel_git_version=${bisect_id} --tags kernel-build --skip-tags delete
