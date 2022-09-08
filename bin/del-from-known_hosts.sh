#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8

for name in ${@}
do
  sed -i -e "/^${name} /d" ~/.ssh&known_hosts
done
