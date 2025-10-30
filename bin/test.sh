#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..
source ./bin/lib.sh

if [[ ${1-} == "app" ]]; then
  names=$(eval echo h{n,s,t}0-{db,dt}-{amd,arm}-{ltsrc,master}-{,no}bp-{,no}cl-0 h{n,s,t}0-un-{amd,arm}-{ltsrc,master}-x-x-0)

  time ./bin/create-server.sh ${names}
  time ./site.yaml --limit "$(xargs <<<${names} | tr ' ' ',')"
  time ./bin/delete-server.sh ${names}

elif [[ ${1-} == "kernel" ]]; then
  names=$(eval echo hi-{db,dt}-{amd,arm,intel}-{ltsrc,master,stablerc}-{,no}bp-{,no}cl hi-un-{amd,arm,intel}-{ltsrc,master,stablerc})

  time ./bin/create-server.sh ${names}
  ./site-snapshot.yaml -e delete_instance_afterwards=true --skip-tags snapshot
  time ./bin/delete-server.sh ${names} 2>/dev/null
fi
