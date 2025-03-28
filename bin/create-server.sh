#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# e.g.:
#   create-server.sh $(seq -w 0 9 | xargs -r -n 1 printf "foo%i ")
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

# both US and Singapore are more expensive and have less traffic incl.
data_centers=$(
  hcloud datacenter list --output json |
    jq -r '.[] | select(.location.name == ("'$(sed -e 's/ /","/g' <<<${HCLOUD_LOCATIONS-fsn1 hel1 nbg1})'"))'
)

server_types=$(hcloud server-type list --output json)
cax11_id=$(jq -r '.[] | select(.name=="cax11") | .id' <<<${server_types}) # ARM
cpx11_id=$(jq -r '.[] | select(.name=="cpx11") | .id' <<<${server_types}) # AMD
cx22_id=$(jq -r '.[] | select(.name=="cx22") | .id' <<<${server_types})   # Intel

cax11_locations=$(jq -r 'select(.server_types.available | contains(['${cax11_id}'])) | .location.name' <<<${data_centers})
cpx11_locations=$(jq -r 'select(.server_types.available | contains(['${cpx11_id}'])) | .location.name' <<<${data_centers})
cx22_locations=$(jq -r 'select(.server_types.available | contains(['${cx22_id}'])) | .location.name' <<<${data_centers})
used_locations=$(echo ${cax11_locations} ${cpx11_locations} ${cx22_locations} | xargs -n 1 | sort -u)

# default OS: recent Debian
image_list=$(hcloud image list --type system --output noheader --output columns=name | sort -ur --version-sort)
image_default=$(grep '^debian' <<<${image_list} | head -n 1)

# image snapshots (if any)
snapshots=$(hcloud image list --type snapshot --output noheader --output columns=id,description | sort -nr)

# currently only 1 key is used
ssh_keys=$(hcloud ssh-key list --output json)
ssh_key=$(jq -r '.[].name' <<<${ssh_keys} | head -n 1)

if [[ -z ${used_locations} || -z ${ssh_key} ]]; then
  echo " API query failed" >&2
  exit 1
fi

now=${EPOCHSECONDS}

if xargs -n 1 <<<$* | grep -Ev "^[a-z0-9\-]+$"; then
  echo " ^^ invalid hostname" >&2
  exit 2
fi

echo -e " creating ..."
set -o pipefail
xargs -n 1 <<<$* |
  while read -r name; do
    # the silicon
    if [[ -n ${HCLOUD_TYPES-} ]]; then
      htype=$(xargs -n 1 <<<${HCLOUD_TYPES} | shuf -n 1)
    else
      # default: smallest type
      case ${name} in
      *-amd-*) htype="cpx11" ;;
      *-arm-*) htype="cax11" ;;
      *-intel-*) htype="cx22" ;;
      *) htype=$(xargs -n 1 <<<"cax11 cpx11 cx22" | shuf -n 1) ;;
      esac
    fi

    if [[ -z ${htype} ]]; then
      echo " error: no htype for ${name}" >&2
      exit 3
    fi

    # e.g. US have only AMD
    case ${htype} in
    cax11) loc=$(xargs -n 1 <<<${cax11_locations} | shuf -n 1) ;;
    cpx11) loc=$(xargs -n 1 <<<${cpx11_locations} | shuf -n 1) ;;
    cx22) loc=$(xargs -n 1 <<<${cx22_locations} | shuf -n 1) ;;
    *)
      echo " error: no location for ${name}" >&2
      exit 4
      ;;
    esac

    # HCLOUD_DEFAULT_IMAGE rules for "snapshot" if "name" does not match a "description"
    image=${HCLOUD_DEFAULT_IMAGE:-$image_default}
    if [[ ${HCLOUD_IMAGE-} == "snapshot" ]]; then
      # shapshots are sorted from newest to oldest
      while read -r id description; do
        if [[ ${name} =~ ${description} ]]; then
          image=${id}
          break
        fi
      done <<<${snapshots}
    elif [[ -n ${HCLOUD_IMAGE-} ]]; then
      image=${HCLOUD_IMAGE}
    fi

    if [[ -z ${image} ]]; then
      echo " error: no image for ${name}" >&2
      exit 5
    fi

    echo "server create --image ${image} --ssh-key ${ssh_key} --name ${name} --location ${loc} --type ${htype}"
  done |
  xargs -r -P ${jobs} -L 1 hcloud --quiet

$(dirname $0)/update-dns.sh

# wait at least half a minute to let (the first created) system come up
diff=$((EPOCHSECONDS - now))
if [[ ${diff} -lt 30 ]]; then
  wait=$((30 - diff))
  echo -en "\n waiting ${wait} sec ..."
  sleep ${wait}
fi

# clean up any left over SSH key
xargs -r $(dirname $0)/distrust-host-ssh-key.sh <<<$*

# establish SSH trust relationship
while ! xargs -r $(dirname $0)/trust-host-ssh-key.sh <<<$*; do
  echo -e " waiting 5 sec ..."
  sleep 5
  echo
done
