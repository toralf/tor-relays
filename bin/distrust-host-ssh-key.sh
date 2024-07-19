#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

echo -e "\n dis-trust host ssh key ..."

xargs -r -n 1 ssh-keygen -R <<<$* >/dev/null
