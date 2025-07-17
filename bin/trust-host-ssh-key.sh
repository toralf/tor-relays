#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

while :; do
  unknowns=$(
    xargs -n 1 <<<$* |
      while read -r name; do
        grep -q -m 1 "^${name} " ~/.ssh/known_hosts || echo ${name}
      done
  )

  echo -en "\n $(wc -w <<<${unknowns}) ssh host/s to scan ..."
  if [[ -z ${unknowns} ]]; then
    break
  fi

  if ssh-keyscan -4 -t ed25519 ${unknowns} >~/.ssh/known_hosts_tmp; then
    grep -v '#' ~/.ssh/known_hosts_tmp >>~/.ssh/known_hosts
    rm ~/.ssh/known_hosts_tmp
    echo -e " ."
  fi
done

echo -e " OK"
