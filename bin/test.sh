#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# build + deploy tests

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..

trap 'echo "  ^^    systems:    ${names}"' INT QUIT TERM EXIT

if [[ ${1-} == "app" ]]; then
  names=$(eval echo h{n,s,t}a-{db,dt}-{amd,arm}-{ltsrc,master}-{,no}bp-{,no}cl-42 h{n,s,t}a-un-{amd,arm}-{ltsrc,master}-x-x-42)
  time ./bin/create-server.sh ${names}
  time ./site-test.yaml --limit "hna-*-42,hsa-*-42,hta-*-42" --skip-tags shutdown,snapshot

elif [[ ${1-} == "image" ]]; then
  names=$(eval echo hi-{db,dt,un}-{arm,x86}-{ltsrc,master,stablerc})
  time ./bin/create-server.sh ${names}
  time ./site-test.yaml --limit "hi-*" --skip-tags autoupdate,kernel-src
  # remove outdated snapshots
  hcloud --quiet image list --type snapshot --output noheader --output columns=id,description |
    sort -r |
    awk 'x[$2]++ { print $1 }' |
    xargs -r hcloud --poll-interval 5s image delete 1>/dev/null

elif [[ ${1-} == "kernel" ]]; then
  names=$(eval echo hik-{db,dt}-{amd,arm,intel}-{ltsrc,master,stablerc}-{,no}bp-{,no}cl-42 hik-un-{amd,arm,intel}-{ltsrc,master,stablerc}-x-x-42)
  time ./bin/create-server.sh ${names}
  time ./site-test.yaml --limit "hik-*-42" --skip-tags autoupdate,shutdown,snapshot

else
  exit 1
fi

time ./bin/delete-server.sh ${names}

trap - INT QUIT TERM EXIT
