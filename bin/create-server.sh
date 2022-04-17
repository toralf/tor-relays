#!/bin/bash
# set -x

set -euf
export LANG=C.utf8

# set Hetzner project
project=${1:?}
hcloud context use ${project}
shift

loc_list=( $(hcloud location list | awk ' NR > 1  { print $2 } ') )

# create at an arbitrarily chosen Hetzner location
for name in ${@}
do
  loc=${loc_list[ ((RANDOM%4)) ]}
  case ${loc} in
    ash)  type="cpx11";;
      *)  type="cx11";;
  esac

  echo -e "\n location: ${loc}"
  hcloud server create \
      --image "debian-11" \
      --ssh-key "tfoerste@t44" \
      --location "${loc}" \
      --type "${type}" \
      --name "${name}"
done

# update /etc/unbound/hetzner-${project}.conf
$(dirname $0)/update-dns.sh ${project}

# update ~/.ssh/known_hosts
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
  echo -n "\nFAILED to reach: ${name}\n"
done
