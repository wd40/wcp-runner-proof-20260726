#!/bin/sh
set -eu

key="ACTIONS_RUNNER_INPUT_""JITCONFIG"
current_uid="$(id -u)"

if env | /bin/grep -F "${key}=" >/dev/null; then
  exit 70
fi

ptrace_scope="$(/bin/cat /proc/sys/kernel/yama/ptrace_scope)"
case "${ptrace_scope}" in
  1|2|3) ;;
  *) exit 71 ;;
esac

for status_path in /proc/[0-9]*/status; do
  pid="${status_path#/proc/}"
  pid="${pid%/status}"
  uid="$(/usr/bin/awk '$1 == "Uid:" { print $2; exit }' "${status_path}" 2>/dev/null || true)"
  if [ "${uid}" != "${current_uid}" ]; then
    continue
  fi
  if /bin/cat "/proc/${pid}/environ" 2>/dev/null |
    /bin/grep -F "${key}=" >/dev/null; then
    exit 72
  fi
  if /bin/cat "/proc/${pid}/cmdline" 2>/dev/null |
    /bin/grep -F -- "--jitconfig" >/dev/null; then
    exit 73
  fi
done

for custody_root in /runner/_diag /runner/_work /tmp; do
  if /bin/grep -R -F -- "${key}=" "${custody_root}" >/dev/null 2>&1; then
    exit 74
  fi
done

for state_path in \
  /runner/.runner \
  /runner/.credentials \
  /runner/.credentials_rsaparams \
  /wcp-jit-state/.runner \
  /wcp-jit-state/.credentials \
  /wcp-jit-state/.credentials_rsaparams; do
  if /bin/cat "${state_path}" >/dev/null 2>&1; then
    exit 75
  fi
done

printf '%s\n' '{"argv_contains_jit":false,"diagnostics_contains_jit":false,"job_environment_contains_jit":false,"output_contains_jit":false,"process_environment_contains_jit":false,"work_contains_jit":false}'
