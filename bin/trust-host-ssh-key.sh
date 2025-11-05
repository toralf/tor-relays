#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

names=$(xargs -n 1 <<<$*)
echo -n " trusting $(wc -w <<<${names}) system/s ..."

attempts=5
while ((attempts--)); do
  unknowns=$(
    while read -r name; do
      if ! grep -q -m 1 "^${name} " ~/.ssh/known_hosts; then
        echo ${name}
      fi
    done <<<${names}
  )
  echo -en "\n  $(wc -w <<<${unknowns}) unknown/s left ..."
  if [[ -z ${unknowns} ]]; then
    break
  fi

  if ssh-keyscan -4 -t ed25519 ${unknowns} >~/.ssh/known_hosts_tmp; then
    grep -v '#' ~/.ssh/known_hosts_tmp >>~/.ssh/known_hosts
    rm ~/.ssh/known_hosts_tmp
  elif ((attempts)); then
    echo -n "  waiting 5s ... "
    sleep 5
  fi
done

echo
if [[ -z ${unknowns} ]]; then
  echo " OK"
else
  echo -e "\n NOT ok,  unknowns:     ${unknowns}\n"
  exit 1
fi
