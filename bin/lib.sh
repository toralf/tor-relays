# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# hint: ./.wellknown entries will not cleaned here

function cleanLocalDataEntries() {
  local d
  d=$(dirname $0)

  echo -e " deleting local entries and facts ..."
  set +e
  while read -r name; do
    [[ -n ${name} ]] || continue
    # Ansible facts
    rm -f $d/../.ansible_facts/${name}
    # line in files under ~/tmp
    sed -i -e "/^${name} /d" -e "/^${name}$/d" -e "/^${name}:[0-9]*$/d" -e "/\"${name}:[0-9]*\"/d" ~/tmp/*_* 2>/dev/null
    # private Tor bridge lines
    sed -i -e "/ # ${name}$/d" /tmp/*_bridgeline 2>/dev/null
  done < <(xargs -n 1 <<<$*)
  set -e
}

function cleanLocalDataFiles() {
  local d
  d=$(dirname $0)

  echo -e " deleting local data files ..."
  set +e
  while read -r name; do
    # certain files in ~/tmp subdirs
    rm -f ~/tmp/{ddos,ddos6}/${name} ~/tmp/{ddos,ddos6}/${name}.*
    # client certs
    rm -f $d/../secrets/ca/*/clients/{crts,csrs,keys}/${name}.{crt,csr,key}
  done < <(xargs -n 1 <<<$*)
  set -e
}

# prefer...
#   ... to match "hiu-intel-stablerc" to "u-intel-stablerc" and only as a fallback to "u-intel-stable"
#   ... younger snapshot (== higher id)

function setSnapshots() {
  snapshots=$(hcloud image list --type snapshot --output noheader --output columns=description,id | sort -r -n)
}

function setImage() {
  if [[ ${LOOKUP_SNAPSHOT-} == "n" ]]; then
    setImageByHostname
  else
    if ! setImageBySnapshot; then
      setImageByHostname
    fi
  fi

  [[ -n ${image} ]]
}

function setImageByHostname() {
  # name example: hiu-amd-main
  if [[ ${name} =~ ^hid- || ${name%%-*} =~ d$ ]]; then
    image="debian-12"
  elif [[ ${name} =~ ^hiu- || ${name%%-*} =~ u$ ]]; then
    image="ubuntu-24.04"
  else
    image=${HCLOUD_FALLBACK_IMAGE:-"debian-12"}
  fi
}

function setImageBySnapshot() {
  if [[ -z ${snapshots} ]]; then
    return 1
  fi

  while read -r description id; do
    if [[ -n ${description} ]]; then
      if [[ ${name} == hi${description} ]]; then
        image=${id}
        return
      fi
    fi
  done <<<${snapshots}

  while read -r description id; do
    if [[ -n ${description} ]]; then
      if [[ ${name} =~ ${description} ]]; then
        # shellcheck disable=SC2034
        image=${id}
        return
      fi
    fi
  done <<<${snapshots}

  return 1
}
