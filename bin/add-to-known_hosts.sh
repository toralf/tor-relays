#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x


set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

while read -r i
do
  if ! ssh -q -oStrictHostKeyChecking=accept-new -oConnectTimeout=1 -oConnectionAttempts=6 $i "uname -a" </dev/null >/dev/null; then
    echo " issue for $i"
  fi
done < <(xargs -n 1 <<< $@)
echo
