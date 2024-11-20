#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

echo -e "\n dis-trust host ssh key ..."

if xargs -r -n 1 ssh-keygen -R <<<$* >/dev/null; then
  echo -e "\n OK\n"
else
  echo -e "\n NOT ok\n"
  exit 1
fi
