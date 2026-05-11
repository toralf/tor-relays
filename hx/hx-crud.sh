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

    # create, rebuild, delete
    if [[ ${action} != "setup" ]]; then
      if ! ./bin/${action}-server.sh ${names} &>${logprefix}.job.${action}.log; then
        info "  NOT ok" >&2
      fi
    fi
    # create, rebuild, setup
    if [[ ${action} != "delete" ]]; then
      if ! ./site-setup.yaml --limit "$(tr ' ' ',' <<<${names})" &>${logprefix}.job.${action}.log; then
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
  local names

  info "is_down"
  if ./site-setup.yaml --limit 'hx,!hix' --tags poweron -e '{ "infodir": "~/tmp/hx" }' &>${logprefix}.is_down.log; then
    info "  NOT ok" >&2
  fi

  names=$(
    grep "^h" ~/tmp/hx/is_down 2>/dev/null |
      grep -v "^hi-" |
      shuf |
      xargs -r
  )

  if [[ -n ${names} ]]; then
    info "  down: $(wc -w <<<${names})"
    shuf -n 64 -e ${names} >~/tmp/hx/job.${EPOCHSECONDS}.rebuild

    info "  power off"
    if ! xargs -n 1 -P $(($(nproc) / 2)) hcloud --quiet --poll-interval 10s server poweroff <<<${names} &>${logprefix}.off.log; then
      info "  NOT ok" >&2
    fi
    info "  power on"
    if ! xargs -n 1 -P $(($(nproc) / 2)) hcloud --quiet --poll-interval 10s server poweron <<<${names} &>${logprefix}.on.log; then
      info "  NOT ok" >&2
    fi
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
