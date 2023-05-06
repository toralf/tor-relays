#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

echo -n " add to ~/.ssh/known_hosts: "
while read -r name; do
  if ssh -q -oStrictHostKeyChecking=accept-new -oConnectTimeout=1 -oConnectionAttempts=6 $name ":" </dev/null; then
    echo -n '.'
  else
    echo " $name failed"
  fi
done < <(xargs -n 1 <<<$*)
echo
