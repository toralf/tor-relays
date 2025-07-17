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
source $(dirname $0)/lib.sh

hash -r hcloud jq

[[ $# -ne 0 ]]
setProject

jobs=$((3 * $(nproc)))
[[ ${jobs} -gt 48 ]] && jobs=48

if xargs -n 1 <<<$* | grep -Ev "^[a-z0-9\-]+$"; then
  echo " ^^ invalid hostname/s" >&2
  exit 2
fi

if [[ ${HCLOUD_DICE_LOCATIONS-} == "y" ]]; then
  # US and Singapore are more expensive and do have less traffic incl.
  data_centers=$(
    hcloud datacenter list --output json |
      jq -r '.[] | select(.location.name == ("'$(sed -e 's/ /","/g' <<<${HCLOUD_LOCATIONS-fsn1 hel1 nbg1})'"))'
  )

  # US has only AMD
  server_types=$(hcloud server-type list --output json)
  cax_id=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${server_types}) # ARM
  cpx_id=$(jq -r '.[] | select(.name=="cpx11") | .id' <<<${server_types}) # AMD
  cx_id=$(jq -r '.[] | select(.name=="cx22") | .id' <<<${server_types})   # Intel

  cax_locations=$(jq -r 'select(.server_types.available | contains(['${cax_id}'])) | .location.name' <<<${data_centers})
  cpx_locations=$(jq -r 'select(.server_types.available | contains(['${cpx_id}'])) | .location.name' <<<${data_centers})
  cx_locations=$(jq -r 'select(.server_types.available | contains(['${cx_id}'])) | .location.name' <<<${data_centers})
fi

if [[ ${LOOKUP_SNAPSHOT-} != "n" ]]; then
  setSnapshots
fi

# take the first one
ssh_key=$(hcloud ssh-key list --output json | jq -r '.[0].name')

echo -e " creating $(wc -w <<<$*) system/s: $(cut -c -16 <<<$*)..."

xargs -n 1 <<<$* |
  while read -r name; do
    # arch
    htype=$(xargs -n 1 <<<${HCLOUD_TYPES:-cax11 cpx11 cx22} | shuf -n 1)
    case ${name} in
    *-amd-*) htype="cpx11" ;;
    *-arm-*) htype="cax11" ;;
    *-intel-*) htype="cx22" ;;
    esac

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

    setImage
    [[ ${image} =~ ^[0-9]+$ ]] && poll_interval="30s" || poll_interval="10s"
    echo --poll-interval ${poll_interval} server create --image ${image} --type ${htype} --ssh-key ${ssh_key} --name ${name} ${loc}

  done |
  xargs -r -P ${jobs} -L 1 hcloud --quiet

$(dirname $0)/update-dns.sh

# do no longer trust old SSH keys
$(dirname $0)/distrust-host-ssh-key.sh $*

# build SSH trust relationship
$(dirname $0)/trust-host-ssh-key.sh $*
