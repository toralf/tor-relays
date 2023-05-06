#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

while read -r name; do
  if ! ssh -q -oStrictHostKeyChecking=accept-new -oConnectTimeout=1 -oConnectionAttempts=6 $name "uname -a" </dev/null >/dev/null; then
    echo " could not get pub ssh host key for $name"
  fi
done < <(xargs -n 1 <<<$*)
