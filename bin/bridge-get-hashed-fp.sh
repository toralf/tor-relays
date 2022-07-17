#!/bin/bash
# set -x

set -euf
export LANG=C.utf8

cd $(dirname $0)/..

ansible-playbook playbooks/info.yaml -e @secrets/local.yaml -t hashed_fingerprint |\
grep "msg" |\
cut -f4 -d '"' |\
sort |\
sed -e 's,  ,\n,g'
