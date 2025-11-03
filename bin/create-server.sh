#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   LOOKUP_SNAPSHOT=n ./bin/create-server.sh foo-{{0..7},{a..f}}
#   HCLOUD_TYPES=cax11 ./bin/create-server.sh foo bar
#   HCLOUD_LOCATIONS="ash hil fsn1 hel1 nbg1" ./bin/create-server.sh baz

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

cd $(dirname $0)/..
source ./bin/lib.sh

hash -r hcloud jq

[[ $# -ne 0 ]]
setProject

jobs=24

names=$(xargs -n 1 <<<$*)

if grep -Ev "^[a-z0-9\-]+$" <<<${names}; then
  echo " ^^ invalid hostname/s" >&2
  exit 2
fi

if [[ ${HCLOUD_DICE_LOCATIONS-} == "y" ]]; then
  # US and Singapore are more expensive and do have less traffic incl.
  data_centers=$(
    hcloud --quiet datacenter list --output json |
      jq -r '.[] | select(.location.name == ("'$(sed -e 's/ /","/g' <<<${HCLOUD_LOCATIONS-fsn1 hel1 nbg1})'"))'
  )

  # US has only AMD
  server_types=$(hcloud --quiet server-type list --output json)
  cax_id=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${server_types}) # ARM
  cpx_id=$(jq -r '.[] | select(.name=="cpx11") | .id' <<<${server_types}) # AMD
  cx_id=$(jq -r '.[] | select(.name=="cx22") | .id' <<<${server_types})   # Intel

  cax_locations=$(jq -r 'select(.server_types.available | contains(['${cax_id}'])) | .location.name' <<<${data_centers})
  cpx_locations=$(jq -r 'select(.server_types.available | contains(['${cpx_id}'])) | .location.name' <<<${data_centers})
  cx_locations=$(jq -r 'select(.server_types.available | contains(['${cx_id}'])) | .location.name' <<<${data_centers})
fi

if [[ ${LOOKUP_SNAPSHOT-} != "n" ]]; then
  snapshots=$(getSnapshots)
fi

# take the first one
ssh_key=$(hcloud --quiet ssh-key list --output json | jq -r '.[0].name')

echo -e " creating $(wc -w <<<${names}) system/s ..."

commands=$(
  while read -r name; do
    # set htype based on hostname
    case ${name} in
    *-amd | *-amd-*) htype="cpx11" ;;
    *-arm | *-arm-*) htype="cax11" ;;
    *-intel | *-intel-*) htype="cx22" ;;
    *-x86 | *-x86-*) htype=$(xargs -n 1 <<<"cpx11 cx22" | shuf -n 1) ;;
    *) htype=$(xargs -n 1 <<<${HCLOUD_TYPES:-cax11 cpx11 cx22} | shuf -n 1) ;;
    esac

    # no preferences for the location
    loc=""
    if [[ -n ${HCLOUD_LOCATION-} ]]; then
      loc="--location ${HCLOUD_LOCATION}"
    elif [[ ${HCLOUD_DICE_LOCATIONS-} == "y" ]]; then
      case ${htype} in
      cax*) loc="--location "$(xargs -n 1 <<<${cax_locations} | shuf -n 1) ;;
      cpx*) loc="--location "$(xargs -n 1 <<<${cpx_locations} | shuf -n 1) ;;
      cx*) loc="--location "$(xargs -n 1 <<<${cx_locations} | shuf -n 1) ;;
      esac
    fi

    image=$(getImage)
    if [[ -z ${image} ]]; then
      echo " ERROR: empty image for ${name}" >&2
      exit 1
    fi

    echo --poll-interval $((1 + jobs / 2))s server create --image ${image} --type ${htype} --ssh-key ${ssh_key} --name ${name} ${loc}
  done <<<${names}
)

set +e
xargs -r -P ${jobs} -L 1 timeout 10m hcloud --quiet <<<${commands}
rc=$?
set -e

if [[ ${rc} -eq 0 || ${rc} -eq 123 ]]; then
  echo " OK"
  ./bin/update-dns.sh
  ./bin/trust-host-ssh-key.sh ${names}
else
  echo " NOT ok, rc=${rc}"
  exit ${rc}
fi
