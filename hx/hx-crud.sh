#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

function _git_ls_remote() {
  local group name
  local url ver tok

  group=${1?GROUP MUST BE GIVEN}
  name=${2?NAME MUST BE GIVEN}

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
    awk '{ print $1 }' |
    grep .
}

function _git_changed() {
  local group name current_id old_id

  group=${1?GROUP MUST BE GIVEN}
  name=${2?NAME MUST BE GIVEN}

  # handle remote git issues
  if ! current_id=$(_git_ls_remote ${group} ${name}); then
    return 4
  fi
  if [[ -z ${current_id} ]]; then
    return 3
  fi

  old_id=$(cat ~/tmp/hx/git.${group}.${name} 2>/dev/null) || true
  # update timestamp of last check
  echo ${current_id} >~/tmp/hx/git.${group}.${name}

  # an empty "old_id" is taken as "unchanged"
  if [[ -z ${old_id} || ${old_id} == "${current_id}" ]]; then
    return 1
  fi

  info "git ${group} ${name}: $(cut -c -12 <<<${old_id}) -> $(cut -c -12 <<<${current_id})"
  return 0
}

function _go_changed() {
  local go_ver_inventory go_ver_upstream

  if ! go_ver_inventory=$(grep -Eo "'go[1-9]+\.[0-9]+\.[0-9]+'" inventory/systems-hetzner-test.yaml); then
    return 5
  fi
  if [[ -z ${go_ver_inventory} || ${go_ver_inventory} =~ " " || ${go_ver_inventory} =~ $'\n' ]]; then
    return 4
  fi
  # surround it by single quotes here
  if ! go_ver_upstream=\'$(curl -s --follow 'https://golang.org/VERSION?m=text' | head -n 1)\'; then
    return 3
  fi
  if [[ -z ${go_ver_upstream} ]]; then
    return 2
  fi
  if [[ ${go_ver_inventory} == "${go_ver_upstream}" ]]; then
    return 1
  fi

  info "Go: ${go_ver_inventory}  ->  ${go_ver_upstream}"
  sed -i -E "s,'go[1-9]+\.[0-9]+\.[0-9]+',${go_ver_upstream}," inventory/systems-hetzner-test.yaml
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
    echo ${job} >${logprefix}.job.log

    if [[ -x ./bin/${action}-server.sh ]]; then
      info "  action ${action}: $(wc -w <<<${names})"
      if ! ./bin/${action}-server.sh ${names} &>>${logprefix}.job.log; then
        info "  NOT ok" >&2
      fi
      pit_stop crud
    fi

    if [[ ${action} == "update" ]]; then
      info "  update: $(wc -w <<<${names})"
      if ! ./site-setup.yaml --limit $(tr ' ' ',' <<<${names}) --tags upgrade,golang,lyrebird,snowflake,tor,kernel-build \
        -e '{ "kernel_git_build_wait": false }' &>>${logprefix}.job.log; then
        info "  NOT ok" >&2
      fi
      pit_stop crud

    elif [[ ${action} != "delete" ]]; then
      info "  setup after ${action}"
      if ! ./site-setup.yaml --limit "$(tr ' ' ',' <<<${names})" \
        -e '{ "kernel_git_build_wait": false }' &>>${logprefix}.job.log; then
        info "  NOT ok" >&2
      fi
      pit_stop crud
    fi

  done < <(
    find ~/tmp/hx -maxdepth 1 -type f \( -name "job.*.create" -o -name "job.*.delete" -o -name "job.*.rebuild" -o -name "job.*.setup" -o -name "job.*.update" \) |
      sort -V
  )
}

function update_app() {
  if _go_changed; then
    if ! ./site-setup.yaml --limit 'hbx,hpx,hsx' --tags tools,lyrebird,snowflake &>${logprefix}.golang.log; then
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

function trigger_kernel_update() {
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
      xargs -r -n 1 |
      shuf
  )
}

function handle_down_systems() {
  local names

  info "down"
  truncate -s 0 ~/tmp/hx/is_down # might contain obsolete entries
  rm -f ~/tmp/hx/is_down_{1,2}

  # 1st ping
  info "  ping 1"
  if ./site-setup.yaml --limit 'hx,!hix' --tags ping -e '{ "infodir": "~/tmp/hx" }' &>${logprefix}.ping_1.log; then
    info "  NOT ok" >&2
  fi
  sort ~/tmp/hx/is_down >~/tmp/hx/is_down_1
  names=$(xargs -r <~/tmp/hx/is_down_1)
  info "  ping 1 down: $(wc -w <<<${names})"
  if [[ -z ${names} ]]; then
    return
  fi

  pit_stop crud

  # 2nd ping
  info "  ping 2"
  if ./site-setup.yaml --limit "$(tr ' ' ',' <<<${names})" --tags ping -e '{ "infodir": "~/tmp/hx" }' &>${logprefix}.ping_2.log; then
    info "  NOT ok" >&2
  fi
  sort ~/tmp/hx/is_down >~/tmp/hx/is_down_2
  info "  ping 2 down: $(wc -w <~/tmp/hx/is_down_2)"

  # was down and is still down
  names=$(comm -12 ~/tmp/hx/is_down_1 ~/tmp/hx/is_down_2 | xargs -r)
  if [[ -n ${names} ]]; then
    info "  needs a rebuild: $(wc -w <<<${names})"
    shuf -n 64 -e ${names} >~/tmp/hx/job.${EPOCHSECONDS}.rebuild
  fi

  # was down but is now pingable
  names=$(comm -23 ~/tmp/hx/is_down_1 ~/tmp/hx/is_down_2 | xargs -r)
  if [[ -n ${names} ]]; then
    info "  needs an update: $(wc -w <<<${names})"
    cat <<<${names} >~/tmp/hx/job.${EPOCHSECONDS}.update
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
  update_app
  trigger_kernel_update
  handle_down_systems

  pit_stop crud 300
done
