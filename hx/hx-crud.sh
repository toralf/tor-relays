#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

function _git_ls_remote() {
  local group=${1?GROUP MUST BE GIVEN}
  local name=${2?NAME MUST BE GIVEN}

  local url ver tok

  if [[ ${group} == "app" ]]; then
    case ${name} in
    lyrebird | snowflake) url=https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/${name}.git ;;
    tor) url=https://gitlab.torproject.org/tpo/core/tor.git ;;
    *) return 1 ;;
    esac

  elif [[ ${group} == "kernel" ]]; then
    url=$(yq -r ".hx.vars.hx_repos.${name}.url" <./inventory/systems-hetzner-test.yaml)
    ver=$(yq -r ".hx.vars.hx_repos.${name}.ver" <./inventory/systems-hetzner-test.yaml | sed -e 's,null,,')
    tok=$(yq -r ".hx_repos_${name}_tok" <./secrets/local.yaml | sed -e 's,null,,')
  fi

  ${tok-} git ls-remote --quiet ${url} ${ver:-main} |
    awk '{ print $1 }'
}

# an empty "old_id" is considered as "unchanged"
function _git_changed() {
  local group=${1?GROUP MUST BE GIVEN}
  local name=${2?NAME MUST BE GIVEN}
  local current_id

  current_id=$(_git_ls_remote ${group} ${name})
  if [[ -n ${current_id} ]]; then
    # shellcheck disable=SC2155
    local old_id=$(cat ~/tmp/hx/git.${group}.${name} 2>/dev/null)
    echo ${current_id} >~/tmp/hx/git.${group}.${name}
    if [[ -n ${old_id} && ${old_id} != "${current_id}" ]]; then
      info "git ${group} ${name}: $(cut -c -12 <<<${old_id}) -> $(cut -c -12 <<<${current_id})"
      return 0
    fi
  fi
  return 1
}

function _go_changed() {
  local _go_ver_inventory _go_ver_upstream

  _go_ver_upstream=$(
    curl -s https://go.dev/dl/ |
      grep -oP 'go[1-9]+\.[0-9]+\.[0-9]+\.linux-amd64\.tar\.gz' |
      sort -Vr |
      head -n 1 |
      sed -e 's,\.linux.*,,'
  )

  if [[ -n ${_go_ver_upstream} ]]; then
    _go_ver_inventory=$(yq -r '.hx.vars.go_version' <./inventory/systems-hetzner-test.yaml)

    if [[ ${_go_ver_inventory} != "${_go_ver_upstream}" ]]; then
      info "Go: ${_go_ver_inventory}  ->  ${_go_ver_upstream}"
      sed -i -e "s,^    go_version: go.*,    go_version: ${_go_ver_upstream}," inventory/systems-hetzner-test.yaml
      return 0
    fi
  fi

  return 1
}

function work_on_job_files() {
  local action names job

  while read -r job; do
    info "work on job $(basename ${job})"

    if [[ ! -s ${job} ]]; then
      info "  empty" >&2
      rm ${job}
      continue
    fi
    action=$(cut -f 3 -d '.' <<<${job})
    names=$(xargs <${job})
    mv ${job} /tmp/

    if [[ -x ./bin/${action}-server.sh ]]; then
      info "  ${action}"
      if ! ./bin/${action}-server.sh ${names} &>${logprefix}.job.${action}.log; then
        info "  NOT ok" >&2
      fi
    fi
    if [[ ${action} != "delete" ]]; then
      info "  setup"
      if ! ./site-setup.yaml --limit "$(tr ' ' ',' <<<${names})" &>>${logprefix}.job.${action}.log; then
        info "  NOT ok" >&2
      fi
    fi

    pit_stop crud
  done < <(
    find ~/tmp/hx -maxdepth 1 -type f \( -name "job.*.create" -o -name "job.*.delete" -o -name "job.*.rebuild" -o -name "job.*.setup" \) |
      sort -V
  )
}

function update_tor_apps() {
  if _go_changed; then
    if ! ./site-setup.yaml --limit 'hbx,hpx,hsx' --tags golang,lyrebird,snowflake &>${logprefix}.golang.log; then
      info "  NOT ok" >&2
    fi
    pit_stop crud
  fi

  if _git_changed app lyrebird; then
    if ! ./site-setup.yaml --limit "hbx,hpx" --tags lyrebird &>${logprefix}.app.lyrebird.log; then
      info "  NOT ok" >&2
    fi
    pit_stop crud
  fi

  if _git_changed app snowflake; then
    if ! ./site-setup.yaml --limit "hsx" --tags snowflake &>${logprefix}.app.snowflake.log; then
      info "  NOT ok" >&2
    fi
    pit_stop crud
  fi

  if _git_changed app tor; then
    if ! ./site-setup.yaml --limit "htx" --tags tor &>${logprefix}.app.tor.log; then
      info "  NOT ok" >&2
    fi
    pit_stop crud
  fi
}

function update_linux_kernels() {
  local i

  while read -r i; do
    if _git_changed kernel ${i}; then
      info "update kernel: ${i}"
      if ! ./site-setup.yaml --limit 'hx,!hix,&h*-*-*-'${i}'*' --tags kernel-build \
        -e '{ "kernel_git_build_wait": false }' &>${logprefix}.kernel.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop crud
    fi
  done < <(
    yq -r ".hx.vars.hx_repos | keys" <./inventory/systems-hetzner-test.yaml |
      tr -d '][",' |
      xargs -n 1 |
      shuf
  )
}

function handle_down_systems() {
  local files names

  # get candidates from all places for 1st ping
  rm -f ~/tmp/hx/is_down_{1,2}
  files=$(find ~/tmp/ -mindepth 2 -maxdepth 3 -name is_down ! -empty)
  if [[ -z ${files} ]]; then
    return
  fi
  names=$(grep -h "^h" ${files} | grep -v "^hi-" | sort -u)
  if [[ -z ${names} ]]; then
    return
  fi

  # 1st ping
  info "  ping 1 before: $(wc -w <<<${names})"
  if ./site-setup.yaml --limit "$(tr ' ' ',' <<<${names})" --tags ping -e '{ "infodir": "~/tmp/hx" }' &>${logprefix}.ping_1.log; then
    info "  NOT ok" >&2
  fi
  grep "^h" ~/tmp/hx/is_down | grep -v "^hi-" | sort >~/tmp/hx/is_down_1
  info "  ping 1  after: $(wc -w <~/tmp/hx/is_down_1)"
  if [[ ! -s ~/tmp/hx/is_down_1 ]]; then
    return
  fi

  pit_stop crud

  # 2nd ping
  names=$(xargs <~/tmp/hx/is_down_1)
  info "  ping 2 before: $(wc -w <<<${names})"
  if ./site-setup.yaml --limit "$(tr ' ' ',' <<<${names})" --tags ping -e '{ "infodir": "~/tmp/hx" }' &>${logprefix}.ping_2.log; then
    info "  NOT ok" >&2
  fi
  grep "^h" ~/tmp/hx/is_down | grep -v "^hi-" | sort >~/tmp/hx/is_down_2
  info "  ping 2  after: $(wc -w <~/tmp/hx/is_down_2)"

  # was down and is still down
  names=$(comm -12 ~/tmp/hx/is_down_1 ~/tmp/hx/is_down_2 | xargs -r)
  if [[ -n ${names} ]]; then
    info "  rebuild: $(wc -w <<<${names})"
    shuf -n 64 -e ${names} >~/tmp/hx/job.${EPOCHSECONDS}.rebuild
  fi

  # was down but is now pingable
  names=$(comm -23 ~/tmp/hx/is_down_1 ~/tmp/hx/is_down_2 | xargs -r)
  if [[ -n ${names} ]]; then
    info "  update: $(wc -w <<<${names})"
    if ! ./site-setup.yaml --limit $(tr ' ' ',' <<<${names}) --tags golang,lyrebird,snowflake,tor,kernel-build \
      -e '{ "kernel_git_build_wait": false }' &>${logprefix}.update.log; then
      info "  NOT ok" >&2
    fi
    pit_stop crud
  fi
}

#######################################################################
set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/..
source ./hx/hx-lib.sh

type jq yq >/dev/null

[[ -d ~/tmp/hx ]]
logprefix=~/tmp/hx/$(basename $0)
trap 'echo; echo stopping...; touch ~/tmp/hx/STOP-crud' INT QUIT TERM EXIT

info "pid $$"
pit_stop crud 0

while :; do
  work_on_job_files
  update_tor_apps
  update_linux_kernels
  handle_down_systems

  pit_stop crud 300
done
