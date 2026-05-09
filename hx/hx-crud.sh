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
    url=$(yq <./inventory/systems-hetzner-test.yaml | jq -cr '.hx.vars.hx_repos.'${name}'.url')
    ver=$(yq <./inventory/systems-hetzner-test.yaml | jq -cr '.hx.vars.hx_repos.'${name}'.ver' | sed -e 's,null,,')
    tok=$(yq <./secrets/local.yaml | jq -cr '.hx_repos_'${name}'_tok' | sed -e 's,null,,')
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

function work_on_job_files() {
  local action names

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
  local limit

  for i in $(shuf -e lyrebird snowflake tor); do
    if _git_changed app ${i}; then
      info "update app: ${i}"
      case ${i} in
      lyrebird) limit="hbx,hpx" ;;
      snowflake) limit="hsx" ;;
      tor) limit="htx" ;;
      *) return 1 ;;
      esac
      if ! ./site-setup.yaml --limit "${limit}" --tags ${i} &>${logprefix}.app.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop crud
    fi
  done
}

function update_linux_kernels() {
  local kernels

  kernels=$(
    yq <./inventory/systems-hetzner-test.yaml |
      jq -cr '.hx.vars.hx_repos | keys' |
      tr ',' ' ' |
      tr -d ']["' |
      xargs -n 1 |
      shuf
  )

  for i in ${kernels}; do
    if _git_changed kernel ${i}; then
      info "update kernel: ${i}"
      if ! ./site-setup.yaml --limit 'hx,!hix,&h*-*-*-'${i}'*' --tags kernel-build \
        -e '{ "kernel_git_build_wait": false }' &>${logprefix}.kernel.${i}.log; then
        info "  NOT ok" >&2
      fi
      pit_stop crud
    fi
  done
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
