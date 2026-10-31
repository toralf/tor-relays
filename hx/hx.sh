#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..
source ./hx/hx-lib.sh

if [[ ! -d ~/tmp/hx ]]; then
  mkdir ~/tmp/hx
fi

for i in crud image info; do
  info "${i}"
  if ! pgrep -f ./hx/hx-${i}.sh; then
    ./hx/hx-${i}.sh &>>~/tmp/hx/hx-${i}.sh.log &
  fi
done

echo -e "\n tail -f ~/tmp/hx/hx-{crud,image,info}.sh.log\n"

# touch ~/tmp/hx/STOP-{crud,image,info}
