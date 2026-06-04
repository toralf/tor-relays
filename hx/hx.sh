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

info "crud"
if ! pgrep -f ./hx/hx-crud.sh; then
  ./hx/hx-crud.sh &>>~/tmp/hx/hx-crud.sh.log &
fi

info "image"
if ! pgrep -f ./hx/hx-image.sh; then
  ./hx/hx-image.sh 'mainline|stable$|lts$' &>>~/tmp/hx/hx-image.sh.log &
fi

info "info"
if ! pgrep -f ./hx/hx-info.sh; then
  ./hx/hx-info.sh &>>~/tmp/hx/hx-info.sh.log &
fi

echo -e "\n tail -f ~/tmp/hx/hx-{crud,image,info}.sh.log\n"

# touch ~/tmp/hx/STOP-{crud,image,info}
