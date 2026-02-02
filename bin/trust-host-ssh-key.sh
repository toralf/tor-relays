#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

names=$(xargs -r -n 1 <<<$*)
echo " trusting $(wc -w <<<${names}) system/s ..."

todo=""
while read -r name; do
  if dig +short ${name} | grep -q .; then
    todo+=" ${name}"
  fi
done <<<${names}
echo -n "  $(wc -w <<<${todo}) found in DNS ..."
if [[ ${todo} -eq 0 ]]; then
  echo -e "\n NOT ok"
  exit 1
fi

attempts=7
while ((attempts--)); do
  todo=$(
    while read -r name; do
      if ! grep -q -m 1 "^${name} " ~/.ssh/known_hosts; then
        echo ${name}
      fi
    done <<<${todo}
  )

  if [[ -z ${todo} ]]; then
    echo -e "\n OK"
    break
  fi

  if ((attempts < 6)); then
    sleep 8
  fi
  echo -en "\n    $(wc -w <<<${todo}) to do ..."
  ssh-keyscan -q -4 -t ed25519 ${todo} | sort | tee -a ~/.ssh/known_hosts >/dev/null
done

if [[ -n ${todo} ]]; then
  echo -e " NOT ok,  to do:     $(xargs <<<${todo})\n"
  exit 1
fi
