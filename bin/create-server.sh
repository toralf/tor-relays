#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   create-server.sh foo-{{0..7},{a..f}}
#   HCLOUD_TYPES=cax11 ./bin/create-server.sh foo bar
#   HCLOUD_LOCATIONS="ash hil fsn1 hel1 nbg1" ./bin/create-server.sh baz

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

hash -r hcloud jq

[[ $# -ne 0 ]]
project=$(hcloud context active)
echo -e "\n using Hetzner project ${project:?}"

jobs=$((3 * $(nproc)))
[[ ${jobs} -gt 48 ]] && jobs=48

# US and Singapore are more expensive and do have less traffic incl.
data_centers=$(
  hcloud datacenter list --output json |
    jq -r '.[] | select(.location.name == ("'$(sed -e 's/ /","/g' <<<${HCLOUD_LOCATIONS-fsn1 hel1 nbg1})'"))'
)

server_types=$(hcloud server-type list --output json)
cax_id=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${server_types}) # ARM
cpx_id=$(jq -r '.[] | select(.name=="cpx11") | .id' <<<${server_types}) # AMD
cx_id=$(jq -r '.[] | select(.name=="cx22") | .id' <<<${server_types})   # Intel

cax_locations=$(jq -r 'select(.server_types.available | contains(['${cax_id}'])) | .location.name' <<<${data_centers})
cpx_locations=$(jq -r 'select(.server_types.available | contains(['${cpx_id}'])) | .location.name' <<<${data_centers})
cx_locations=$(jq -r 'select(.server_types.available | contains(['${cx_id}'])) | .location.name' <<<${data_centers})
used_locations=$(echo ${cax_locations} ${cpx_locations} ${cx_locations} | xargs -n 1 | sort -u)

# default OS: recent Debian
image_default=$(hcloud image list --type system --output json | jq -r '.[].name' | grep '^debian' | sort -urV | head -n 1)

# image snapshots
snapshots=$(hcloud image list --type snapshot --output noheader --output columns=id,description | sort -nr)

# works if only 1 key is there
ssh_key=$(hcloud ssh-key list --output json | jq -r '.[0].name')

if [[ -z ${used_locations} || -z ${ssh_key} ]]; then
  echo " API query failed" >&2
  exit 1
fi

if xargs -n 1 <<<$* | grep -Ev "^[a-z0-9\-]+$"; then
  echo " ^^ invalid hostname/s" >&2
  exit 2
fi

echo -e " creating $(wc -w <<<$*) system/s: $(cut -c -16 <<<$*)..."

set -o pipefail
xargs -n 1 <<<$* |
  while read -r name; do
    # arch
    htype=$(xargs -n 1 <<<${HCLOUD_TYPES:-cax11 cpx11 cx22} | shuf -n 1)
    case ${name} in
    *-amd-*) htype="cpx11" ;;
    *-arm-*) htype="cax11" ;;
    *-intel-*) htype="cx22" ;;
    esac

    # e.g. US have only AMD
    if [[ -n ${HCLOUD_LOCATION-} ]]; then
      loc="--location ${HCLOUD_LOCATION}"
    else
      case ${htype} in
      #cax*) loc="--location "$(xargs -n 1 <<<${cax_locations} | shuf -n 1) ;;
      cpx*) loc="--location "$(xargs -n 1 <<<${cpx_locations} | shuf -n 1) ;;
      #cx*) loc="--location "$(xargs -n 1 <<<${cx_locations} | shuf -n 1) ;;
      *) loc="" ;;
      esac
    fi

    poll="15"
    image=${HCLOUD_IMAGE:-$image_default}
    if [[ ${HCLOUD_USE_SNAPSHOT-} == "y" && -n ${snapshots} ]]; then
      # shapshots are sorted from youngest to oldest
      while read -r id description; do
        if [[ ${name} =~ ${description} ]]; then
          poll=$((1 + jobs / 2))
          image=${id}
          break
        fi
      done <<<${snapshots}
    fi
    if [[ -z ${image} ]]; then
      echo " error: no image for ${name}" >&2
      exit 5
    fi

    echo --quiet --poll-interval ${poll}s server create --image ${image} --type ${htype} --ssh-key ${ssh_key} --name ${name} ${loc}
  done |
  xargs -r -P ${jobs} -L 1 hcloud

$(dirname $0)/update-dns.sh

# clean up any old SSH key
$(dirname $0)/distrust-host-ssh-key.sh $*

# build SSH trust relationship
$(dirname $0)/trust-host-ssh-key.sh $*
