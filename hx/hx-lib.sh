# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

function info() {
  echo -e " $(date) $*                            "
}

function pit_stop() {
  local rc=$?
  local sec=${1:-60}
  local stopfile=~/tmp/hx/${2:-STOP}

  info "sleep for ${sec}s"

  while ((sec--)) && [[ ! -f ${stopfile} ]]; do
    sleep 1
  done

  if [[ -f ${stopfile} ]]; then
    set +euf
    trap - INT QUIT TERM EXIT
    echo
    info "caught ${stopfile}\n"
    rm ${stopfile}
    exit ${rc}
  fi
}
