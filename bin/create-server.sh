#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#  ./create-server.sh $(seq -w 0 9 | xargs -r -n 1 printf "foo%i ")
#  HCLOUD_TYPES=cax11 ./bin/create-server.sh foo bar
#  HCLOUD_LOCATIONS="ash hil fsn1 hel1 nbg1" ./bin/create-server.sh baz

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}\n"

jobs=$((2 * $(nproc)))

# US and Singapore are more expensive and/or traffic limited
data_centers=$(
  hcloud datacenter list --output json |
    jq -r '.[] | select(.location.name == ("'$(sed -e "s/ /\",\"/g" <<<${HCLOUD_LOCATIONS-fsn1 hel1 nbg1})'"))'
)

server_types=$(hcloud server-type list --output json)
cax11_id=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${server_types}) # ARM
cpx11_id=$(jq -r '.[] | select(.name=="cpx11") | .id' <<<${server_types}) # AMD
cx22_id=$(jq -r '.[] | select(.name=="cx22") | .id' <<<${server_types})   # Intel

cax11_locations=$(jq -r 'select(.server_types.available | contains(['${cax11_id}'])) | .location.name' <<<${data_centers})
cpx11_locations=$(jq -r 'select(.server_types.available | contains(['${cpx11_id}'])) | .location.name' <<<${data_centers})
cx22_locations=$(jq -r 'select(.server_types.available | contains(['${cx22_id}'])) | .location.name' <<<${data_centers})
used_locations=$(echo ${cax11_locations} ${cpx11_locations} ${cx22_locations} | xargs -n 1 | sort -u)

# OS: use recent Debian
image_list=$(hcloud image list --type system --output columns=name)
debian=$(grep '^debian' <<<${image_list} | sort -ur | head -n 1)

# currently only 1 key is used
ssh_keys=$(hcloud ssh-key list --output json)
ssh_key=$(jq -r '.[].name' <<<${ssh_keys} | head -n 1)

if [[ -z ${used_locations} || -z ${debian} || -z ${ssh_key} ]]; then
  echo " API query failed" >&2
  exit 1
fi

now=${EPOCHSECONDS}

xargs -n 1 <<<$* |
  while read -r name; do
    if [[ ! $name =~ ^[a-z0-9\-]+$ ]]; then
      echo " contains invalid letters: $name" >&2
      exit 2
    fi
  done

set -o pipefail
xargs -n 1 <<<$* |
  while read -r name; do
    if [[ -n ${HCLOUD_TYPES-} ]]; then
      htype=$(xargs -n 1 <<<${HCLOUD_TYPES} | shuf -n 1)
    else
      # default: smallest type
      case ${name} in
      *-amd | *-amd-*) htype="cpx11" ;;
      *-arm | *-arm-*) htype="cax11" ;;
      *-intel | *-intel-*) htype="cx22" ;;
      *) htype=$(xargs -n 1 <<<"cax11 cpx11 cx22" | shuf -n 1) ;;
      esac
    fi

    if [[ -z $htype ]]; then
      echo " error: empty htype for $name" >&2
      exit 4
    fi

    if [[ ${htype} == "cax11" ]]; then
      loc=$(xargs -n 1 <<<${cax11_locations} | shuf -n 1)
    elif [[ ${htype} == "cpx11" ]]; then
      loc=$(xargs -n 1 <<<${cpx11_locations} | shuf -n 1)
    elif [[ ${htype} == "cx22" ]]; then
      loc=$(xargs -n 1 <<<${cx22_locations} | shuf -n 1)
    else
      echo " error: unknown htype ${htype} for $name" >&2
      exit 3
    fi

    if [[ -z $loc ]]; then
      echo " error: empty loc for htype ${htype} for $name" >&2
      exit 4
    fi

    echo "server create --image ${HCLOUD_IMAGE:-$debian} --ssh-key ${ssh_key} --name ${name} --location ${loc} --type ${htype}"
  done |
  xargs -t -r -P ${jobs} -L 1 hcloud --quiet

$(dirname $0)/update-dns.sh

# wait half a minute before ssh into the instance
diff=$((EPOCHSECONDS - now))
if [[ ${diff} -lt 30 ]]; then
  wait=$((30 - diff))
  echo -en "\n waiting ${wait} sec ..."
  sleep ${wait}
fi

while ! xargs -r $(dirname $0)/trust-host-ssh-key.sh <<<$*; do
  echo -e "\n waiting 5 sec ...\n"
  sleep 5
  echo
done
