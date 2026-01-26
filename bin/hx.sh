#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

# goal: CI/CD

function info() {
  echo -e " $(date) $*                            "
}

function wait_for_jobs() {
  # shellcheck disable=SC2155
  local jobs=$(jobs -p | xargs -r)
  if [[ -n ${jobs} ]]; then
    info "jobs: ${jobs}"
    while fg 2>/dev/null; do
      :
    done
  fi
}

function pit_stop() {
  local sec=${1:-60}

  echo -en " $(date) sleeping ${sec}s    \r"
  while ((sec--)); do
    if [[ -f /tmp/STOP ]]; then
      trap - INT QUIT TERM EXIT
      info "caught /tmp/STOP"
      rm /tmp/STOP
      wait_for_jobs
      info "exit\n"
      exit 0
    fi
    if [[ -f /tmp/CONT ]]; then
      rm /tmp/CONT
      echo
      break
    fi
    sleep 1
  done
}

function git_ls_remote() {
  local name=${1?NAME MUST BE GIVEN}

  local url ver
  case ${name} in
  # Tor project
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
  ltsrc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-6.12.y
    ;;
  mainline)
    url=git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
    ver=master
    ;;
  stablerc)
    url=git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
    ver=linux-6.18.y
    ;;
  *)
    echo " ${name} is not implemented"
    exit 2
    ;;
  esac

  git ls-remote --quiet https://${url} ${ver} |
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
set -uf # no -e
set -m
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin:~/bin

cd $(dirname $0)/.. || exit

log=/tmp/$(basename $0)

trap 'echo stopping...; touch /tmp/STOP' INT QUIT TERM EXIT

while :; do
  # app update
  for i in lyrebird snowflake tor; do
    if git_changed $i; then
      info "app: $i"
      limit=""
      case $i in
      lyrebird) limit="hbx,hpx" ;;
      snowflake) limit="hsx" ;;
      tor) limit="htx" ;;
      esac
      ./site-setup.yaml --limit "${limit}" --tags $i &>${log}.$i.log
      pit_stop
    fi
  done

  # kernel update
  for i in ltsrc mainline stablerc; do
    if git_changed $i; then
      info "kernel: $i"
      ./bin/hx-test.sh -t image_build -b $i &>${log}.image_build.$i.log &
      ./site-setup.yaml --limit "hx:!hi:&h*-*-*-${i}*" --tags kernel-build -e kernel_git_build_wait=false &>${log}.$i.log
      pit_stop
    fi
  done

  # update/rebuild
  info "down"
  grep "^h" ~/tmp/tor-relays/is_down >/tmp/is_down.before
  ./site-setup.yaml --limit 'hx:!hi' --tags poweron &>${log}.down.log
  grep "^h" ~/tmp/tor-relays/is_down >/tmp/is_down.after
  pit_stop

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
      RETRY_FILES_ENABLED="True" RETRY_FILES_SAVE_PATH="${HOME}" ./site-setup.yaml \
        --limit "$(tr ' ' ',' <<<${update})" \
        --tags kernel-build,lyrebird,snowflake,tor \
        -e kernel_git_build_wait=false \
        &>${log}.update.log
      pit_stop
    else
      truncate -s 0 ${HOME}/.retry
    fi

    # rebuild broken systems
    retry=$(xargs -r <${HOME}/.retry)
    if [[ -n ${retry} ]]; then
      info "  retry: $(wc -w <<<${retry})"
      wait_for_jobs
      rebuild=$(shuf -n 32 -e ${retry} | xargs)
      ./bin/rebuild-server.sh ${rebuild}
      ./site-setup.yaml --limit "$(tr ' ' ',' <<<${rebuild})" -e kernel_git_build_wait=false &>${log}.rebuild.log
      pit_stop
    fi
  fi

  pit_stop 300
  wait_for_jobs
done
