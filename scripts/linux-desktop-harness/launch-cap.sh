#!/usr/bin/env bash
# Launches Cap in a throwaway profile with the harness hooks. Usage:
#   launch-cap.sh <name> [KEY=VALUE...]
# CAP_ARGS is passed to Cap as its one argument (a deep link).
# Logs go to $HARNESS_OUT/<name>.log; the PID to $XDG_RUNTIME_DIR/<name>.pid.
set -euo pipefail
name=$1
shift
: "${CAP_BIN:=/usr/bin/Cap}"
profile="$HARNESS_OUT/profile"
mkdir -p "$profile/recordings" "$profile/logs"
if [[ ! -f "$profile/store" ]]; then
  cat >"$profile/store" <<'JSON'
{
  "general_settings": {
    "hasCompletedOnboarding": true,
    "enableNotifications": false,
    "enableTelemetry": false,
    "recordingCountdown": 0
  },
  "recording_start_safety": {
    "confirmBeforeRecordingWithoutMicrophone": false
  }
}
JSON
fi
# Probe only: let a native crash leave a core file (core_pattern is set on
# the host to /out/core.*).
ulimit -c unlimited
gdb_prefix=()
if [[ -n ${CAP_GDB:-} ]]; then
  gdb_prefix=(gdb -q -batch -ex "set pagination off"
    -ex "handle SIGPIPE SIGUSR1 SIGUSR2 SIG32 SIG33 SIG34 SIG35 SIG36 nostop noprint pass"
    -ex run -ex "echo GDBSTOP\n" -ex "info registers rip" -ex 'x/6i $pc'
    -ex "bt 60" -ex "info sharedlibrary" -ex "thread apply all bt 25" -ex kill --args)
fi
env \
  CAP_GPUI_APP_DATA_DIR="$profile" \
  CAP_GPUI_RECORDINGS_DIR="$profile/recordings" \
  CAP_GPUI_LOG_DIR="$profile/logs" \
  CAP_GPUI_AUTO_NO_MIC=1 \
  RUST_LOG="${RUST_LOG:-info}" \
  "$@" \
  ${CAP_LAUNCH_PREFIX:-} "${gdb_prefix[@]}" "$CAP_BIN" ${CAP_ARGS:+"$CAP_ARGS"} >"$HARNESS_OUT/$name.log" 2>&1 &
echo $! >"$XDG_RUNTIME_DIR/$name.pid"
echo $!
