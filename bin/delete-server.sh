#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
[[ -n ${project} ]]

jobs=$((1 * $(nproc)))

echo -n " stopping tor service(s) ..."
if xargs -n 1 <<<$* | xargs -r -P ${jobs} -I {} ssh -n -oConnectTimeout=1 -oConnectionAttempts=1 {} "service tor stop &>/dev/null >/dev/null || true"; then
  echo
fi

echo -n " delete ssh hash(es) ... "
if xargs -r -n 1 -P ${jobs} ssh-keygen -R <<<$*; then
  echo
fi

echo -n " delete .ansible_facts and line(s) in tmp files ... "
while read -r name; do
  set +e
  sed -i -e "/^${name} /d" ~/tmp/${project}_* 2>/dev/null
  sed -i -e "/ # ${name}$/d" /tmp/${project}_bridgeline 2>/dev/null
  set -e
  rm -f $(dirname $0)/../.ansible_facts/${name}
done < <(xargs -n 1 <<<$*)
echo

echo -n " collect protected ip(s) ..."
ids=""
while read -r name; do
  for v in ipv4 ipv6; do
    id=$(hcloud server describe ${name} --output=json | jq -cr "select (.public_net.${v}.blocked == true) | .public_net.${v}.id")
    if [[ -n ${id} ]]; then
      ids+="${id} "
    fi
  done
done < <(xargs -n 1 <<<$*)
echo
if [[ -n ${ids} ]]; then
  echo -n " unprotect $(wc -l <<<${ids}) ip(s) ..."
  if xargs -r -n 1 -P ${jobs} hcloud primary-ip update --auto-delete=true <<<${ids}; then
    echo
  fi
fi

echo -n " delete server(s) ..."
if xargs -r -n 1 -P ${jobs} hcloud server delete <<<$*; then
  echo
fi

echo
$(dirname $0)/update-dns.sh
