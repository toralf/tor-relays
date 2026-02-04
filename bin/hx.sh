#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

function git_ls_remote() {
  local name=${1?NAME MUST BE GIVEN}

  local url ver env
  case ${name} in
  # Tor project
  #
  lyrebird)
    url=gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git
    ver="main"
    ;;
  snowflake)
    url=gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake.git
    ver="main"
    ;;
  tor)
    url=gitlab.torproject.org/tpo/core/tor.git
    ver="main"
    ;;
  # kernel
  #
  ltsrc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-6.12.y
    ;;
  mainline)
    url=git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
    ver=master
    # env="GITLAB_API_TOKEN=abcd"
    ;;
  stablerc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-6.18.y
    ;;
  #
  #
  *)
    echo " ${name} is not implemented"
    exit 2
    ;;
  esac

  ${env-} git ls-remote --quiet https://${url} ${ver} |
    awk '{ print $1 }'
}

function git_changed() {
  local name=${1?NAME MUST BE GIVEN}

  # shellcheck disable=SC2155
  local old=$(cat /tmp/git.${name} 2>/dev/null)
  # shellcheck disable=SC2155
  local new=$(git_ls_remote ${name} 2>/dev/null)
  if [[ -n ${new} ]]; then
    echo ${new} >/tmp/git.${name}
    if [[ -n ${old} && ${old} != "${new}" ]]; then
      info "git ${name}: $(cut -c -12 <<<${old}) -> $(cut -c -12 <<<${new})"
      return 0
    fi
  fi
  return 1
}

#######################################################################
set -euf
set -m
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

export RETRY_FILES_ENABLED="True"
export RETRY_FILES_SAVE_PATH="${HOME}"

cd $(dirname $0)/..
source ./bin/hx-lib.sh
trap 'echo stopping...; rm -f /tmp/CONT; touch /tmp/STOP' INT QUIT TERM EXIT

if [[ ! -d /tmp/hx ]]; then
  mkdir /tmp/hx
fi
log=/tmp/hx/$(basename $0)

type hcloud >/dev/null

# too much grep and other calls otherwise to chain
set +e

while :; do
  # Tor app update
  for i in lyrebird snowflake tor; do
    if git_changed $i; then
      info "app: $i"
      limit=""
      case $i in
      lyrebird) limit="hbx,hpx" ;;
      snowflake) limit="hsx" ;;
      tor) limit="htx" ;;
      esac
      if ! ./site-setup.yaml --limit "${limit}" --tags $i &>${log}.$i.log; then
        info "  NOT ok"
      fi
      pit_stop
    fi
  done

  # kernel update
  for i in ltsrc mainline stablerc; do
    if git_changed $i; then
      info "kernel: $i"
      ./bin/hx-test.sh -t image_build -b $i &>${log}.image_build.$i.log &
      if ! ./site-setup.yaml --limit "hx,!hix,&h*-*-*-${i}*" --tags kernel-build -e kernel_git_build_wait=false &>${log}.$i.log; then
        info "  NOT ok"
      fi
      pit_stop
    fi
  done

  # check all systems
  info "check"
  grep "^h" ~/tmp/tor-relays/is_down >/tmp/is_down.before
  if ! ./site-setup.yaml --limit 'hx,!hix' --tags poweron &>${log}.down.log; then
    info "  NOT ok"
  fi
  grep "^h" ~/tmp/tor-relays/is_down >/tmp/is_down.after
  pit_stop

  # update/rebuild
  if [[ -s /tmp/is_down.before || -s /tmp/is_down.after ]]; then

    # power off/on unreachable systems
    power=$(xargs -r </tmp/is_down.after)
    if [[ -n ${power} ]]; then
      info "  power: $(wc -w <<<${power})"
      info "    power off"
      xargs -r -n 1 -P 32 hcloud --quiet --poll-interval 10s server poweroff <<<${power} &>${log}.poweroff.log
      info "    power on"
      xargs -r -n 1 -P 32 hcloud --quiet --poll-interval 10s server poweron <<<${power} &>${log}.poweron.log
      pit_stop
    fi

    # catch up any missed updates
    update=$(sort -u /tmp/is_down.{before,after} | xargs -r)
    if [[ -n ${update} ]]; then
      info "  update: $(wc -w <<<${update})"
      if ! ./site-setup.yaml \
        --limit "$(tr ' ' ',' <<<${update})" \
        --tags kernel-build,lyrebird,snowflake,tor \
        -e kernel_git_build_wait=false \
        &>${log}.update.log; then
        info "  NOT ok"
      fi
      pit_stop
    else
      truncate -s 0 ${HOME}/.retry
    fi

    # rebuild failed systems
    retry=$(xargs -r <${HOME}/.retry)
    if [[ -n ${retry} ]]; then
      info "  retry: $(wc -w <<<${retry})"
      wait_for_jobs
      rebuild=$(shuf -n 64 -e ${retry} | xargs)
      ./bin/rebuild-server.sh ${rebuild}
      if ! ./site-setup.yaml --limit "$(tr ' ' ',' <<<${rebuild})" -e kernel_git_build_wait=false &>${log}.rebuild.log; then
        info "  NOT ok"
      fi
      pit_stop
    fi
  fi

  pit_stop 300
  wait_for_jobs
done
