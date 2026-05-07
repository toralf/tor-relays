# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

function info() {
  echo -e " $(date) $*                            "
}

function pit_stop() {
  local rc=$?
  local contfile=~/tmp/hx/CONT-${1-}
  local stopfile=~/tmp/hx/STOP-${1-}
  local sec=${2:-60}

  info "sleep for ${sec}s"
  while ((sec--)) && [[ ! -f ${contfile} && ! -f ${stopfile} ]]; do
    sleep 1
  done

  rm -f ${contfile}
  if [[ -f ${stopfile} ]]; then
    set +euf
    trap - INT QUIT TERM EXIT
    echo
    info "caught ${stopfile}\n"
    rm ${stopfile}
    exit ${rc}
  fi
}
