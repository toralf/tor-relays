#!/bin/bash
# set -x

set -euf
export LANG=C.utf8

for name in ${@}
do
  i=10
  while ((i--))
  do
    if ssh -oStrictHostKeyChecking=accept-new -oConnectTimeout=5 ${name} "uname -a" </dev/null; then
      continue 2
    fi
    sleep 3
  done
  echo -n "\n FAILED to reach: ${name}\n"
done
