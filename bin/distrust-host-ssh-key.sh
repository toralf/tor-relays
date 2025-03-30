#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

echo -e "\n dis-trusting $(wc -w <<<$*) ssh host key/s ..."

# file-locking of ssh-keygen doesn't work
if xargs -r -P 1 -n 1 ssh-keygen -R <<<$* &>/dev/null; then
  echo -e " OK"
else
  echo -e " NOT ok"
  exit 1
fi
