#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -uf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n ${project} ]]

jobs=$((1 * $(nproc)))

echo -e "\n delete ssh hash(es) ... "
xargs -r -n 1 -P 1 ssh-keygen -R <<<$* # no parallel, it is racy
echo $?

echo -e "\n delete .ansible_facts and line(s) in tmp files ... "
while read -r name; do
  set +e
  sed -i -e "/^${name} /d" ~/tmp/${project}_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/${project}_bridgeline 2>/dev/null
  set -e
  rm -f $(dirname $0)/../.ansible_facts/${name}
done < <(xargs -n 1 <<<$*)

echo -e "\n collect protected ip(s) ..."
ids=""
while read -r name; do
  for v in ipv4 ipv6; do
    id=$(hcloud server describe ${name} --output json | jq -cr "select (.public_net.${v}.blocked == true) | .public_net.${v}.id")
    if [[ -n ${id} ]]; then
      ids+="${id} "
    fi
  done
done < <(xargs -n 1 <<<$*)
if [[ -n ${ids} ]]; then
  echo -e "\n unprotect $(wc -l <<<${ids}) ip(s) ..."
  xargs -r -n 1 -P ${jobs} hcloud primary-ip update --auto-delete=true <<<${ids}
  echo $?
fi

echo -e "\n delete server(s) ..."
xargs -r -n 1 -P ${jobs} hcloud server delete <<<$*
echo $?

echo -e "\n remove from DNS ..."
$(dirname $0)/update-dns.sh
