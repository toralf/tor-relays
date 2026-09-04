#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: keep only the latest snapshot for each description

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

type hcloud >/dev/null

hcloud --quiet image list --type snapshot --output noheader --output columns=id,description |
  sort -rn |
  awk 'x[$2]++ { print $1 }' |
  xargs -r -P 4 hcloud --quiet --poll-interval 10s image delete
