#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

names=$(xargs -r <<<$*)

echo -e "\n dis-trusting $(wc -w <<<${names}) ssh host key/s ..."

if ! xargs -r -n 1 ssh-keygen -R <<<${names} &>/dev/null; then
  echo " NOT ok"
  exit 1
fi

echo " OK"
