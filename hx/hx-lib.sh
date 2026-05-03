# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

function info() {
  echo -e " $(date) $*                            "
}

function pit_stop() {
  local rc=$?
  local sec=${1:-60}
  local stopfile=${2:-STOP}

  echo -en " $(date) sleep for ${sec}s    \r"

  while ((sec--)) && [[ ! -f ~/tmp/hx/${stopfile} ]]; do
    sleep 1
  done

  if [[ -f ~/tmp/hx/${stopfile} ]]; then
    set +euf
    trap - INT QUIT TERM EXIT
    info "caught ${stopfile}\nexit\n"
    exit ${rc}
  fi
}
