#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"

if [ ! -f "${PID_FILE}" ]; then
  echo "VM is not running; no PID file found."
  exit 0
fi

PID=$(cat "${PID_FILE}" 2>/dev/null || true)
case "${PID}" in
  ''|*[!0-9]*)
    rm -f "${PID_FILE}"
    echo "Removed invalid VM PID file."
    exit 0
    ;;
esac

if ! kill -0 "${PID}" 2>/dev/null; then
  rm -f "${PID_FILE}"
  echo "VM is not running; removed stale PID file."
  exit 0
fi

COMMAND=$(ps -p "${PID}" -o args= 2>/dev/null || true)
case "${COMMAND}" in
  *qemu-system-x86_64*go9-freebsd-dev*) ;;
  *)
    rm -f "${PID_FILE}"
    echo "Refusing to signal unrelated process ${PID}; removed stale PID file." >&2
    exit 0
    ;;
esac

kill "${PID}"
i=0
while [ "${i}" -lt 30 ] && kill -0 "${PID}" 2>/dev/null; do
  i=$((i + 1))
  sleep 1
done

if kill -0 "${PID}" 2>/dev/null; then
  kill -9 "${PID}" 2>/dev/null || true
fi

rm -f "${PID_FILE}"
echo "VM stopped."
