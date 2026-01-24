#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   LOOKUP_SNAPSHOT=n ./bin/create-server.sh foo-{{0..7},{a..f}}
#   HCLOUD_TYPES=cax11 ./bin/create-server.sh foo bar
#   HCLOUD_LOCATIONS="ash hil fsn1 hel1 nbg1" ./bin/create-server.sh baz

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..
source ./bin/lib.sh

type hcloud jq >/dev/null

[[ $# -ne 0 ]]
setProject

jobs=24

names=$(xargs -r -n 1 <<<$*)

if grep -Ev "^[a-z0-9\-]+$" <<<${names}; then
  echo " ^^ invalid hostname/s" >&2
  exit 2
fi

export HCLOUD_DICE_LOCATION=${HCLOUD_DICE_LOCATION-y}

if [[ ${HCLOUD_DICE_LOCATION-} == "y" ]]; then
  # US and Singapore are more expensive and do have less traffic incl.
  data_centers=$(
    hcloud --quiet datacenter list --output json |
      jq -r '.[] | select(.location.name == ("'$(sed -e 's/ /","/g' <<<${HCLOUD_LOCATIONS:-fsn1 hel1 nbg1})'"))'
  )

  # US has only AMD
  server_types=$(hcloud --quiet server-type list --output json)
  id_arm=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${server_types}) # ARM
  id_x86=$(jq -r '.[] | select(.name=="cx23") | .id' <<<${server_types})  # AMD/Intel

  locations_arm=$(jq -r 'select(.server_types.available | contains(['${id_arm}'])) | .location.name' <<<${data_centers})
  locations_x86=$(jq -r 'select(.server_types.available | contains(['${id_x86}'])) | .location.name' <<<${data_centers})
fi

if [[ ${LOOKUP_SNAPSHOT-} != "n" ]]; then
  snapshots=$(getSnapshots)
fi

if [[ -n ${SSH_KEY-} ]]; then
  ssh_key=${SSH_KEY}
else
  ssh_key=$(hcloud --quiet ssh-key list --output json | jq -r '.[] | select(.labels.hx == "true") | .name')
  if [[ -z ${ssh_key} ]]; then
    # take the first one
    ssh_key=$(hcloud --quiet ssh-key list --output json | jq -r '.[0].name')
    if [[ -z ${ssh_key} ]]; then
      echo "can't find an ssh key" >&2
      exit 3
    fi
  fi
fi
echo -e " creating $(wc -w <<<${names}) system/s ..."

commands=$(
  while read -r name; do
    # set htype based on hostname
    case ${name} in
    *-arm | *-arm-*) htype="cax11" ;;
    *-x86 | *-x86-*) htype="cx23" ;;
    *) htype=$(xargs -r -n 1 <<<${HCLOUD_TYPES:-cax11 cx23} | shuf -n 1) ;;
    esac

    # location
    if [[ -n ${HCLOUD_LOCATION-} ]]; then
      loc="--location ${HCLOUD_LOCATION}"
    elif [[ ${HCLOUD_DICE_LOCATION-} == "y" ]]; then
      case ${htype} in
      cax*) loc="--location "$(xargs -r -n 1 <<<${locations_arm} | shuf -n 1) ;;
      cx*) loc="--location "$(xargs -r -n 1 <<<${locations_x86} | shuf -n 1) ;;
      esac
    else
      loc=""
    fi

    if [[ -n ${HCLOUD_IMAGE-} ]]; then
      image=${HCLOUD_IMAGE}
    else
      image=$(setImage ${name})
    fi
    if [[ -z ${image} ]]; then
      echo " ERROR: empty image for ${name}" >&2
      exit 1
    fi

    echo --poll-interval $((1 + jobs / 2))s server create --image ${image} --type ${htype} --ssh-key ${ssh_key} --name ${name} ${loc}
  done <<<${names}
)

set +e
xargs -r -P ${jobs} -L 1 timeout 30m hcloud --quiet <<<${commands}
rc=$?
set -e

echo " rc=${rc}"
if [[ ${rc} -eq 0 || ${rc} -eq 123 ]]; then
  echo " OK"
  ./bin/update-dns.sh
  ./bin/trust-host-ssh-key.sh ${names}
else
  echo " NOT ok"
  exit ${rc}
fi
