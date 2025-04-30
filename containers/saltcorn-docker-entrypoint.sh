#!/bin/sh
set -eu

PUID=${PUID:-1000}
PGID=${PGID:-1000}

if [ "$(id -u node)" != "$PUID" ] || [ "$(id -g node)" != "$PGID" ]; then
  echo "Updating node UID:GID to $PUID:$PGID"
  usermod -u "$PUID" node
  groupmod -g "$PGID" node
  chown -R "$PUID:$PGID" /home/node /saltcorn-cli || true
fi

if [ "$#" -eq 0 ]; then
  set -- serve
fi

SALT_COMMANDS="add-schema backup build-app build-cordova-builder configuration-check configuration-check-backups create-tenant create-user delete-tenants delete-user fixtures get-cfg info inspect install-pack install-plugin list-tenants list-triggers list-users migrate modify-user paths plugins reset-schema restore rm-tenant run-benchmark run-js run-sql run-tests run-trigger scheduler serve set-cfg set-daily-time setup setup-benchmark sync-upload-data take-snapshot transform-field dev"

IS_SALTCORN_CMD=0
for cmd in $SALT_COMMANDS; do
  if [ "$1" = "$cmd" ]; then
    IS_SALTCORN_CMD=1
    break
  fi
done

if [ "$IS_SALTCORN_CMD" -eq 1 ]; then
  if [ -n "${SALTCORN_FILE_STORE:-}" ]; then
    if [ -d "$SALTCORN_FILE_STORE" ]; then
      CURRENT_OWNER=$(stat -c '%U' "$SALTCORN_FILE_STORE" 2>/dev/null || echo "")
      if [ "$CURRENT_OWNER" != "node" ]; then
        echo "Fixing ownership of $SALTCORN_FILE_STORE to node:node"
        chown -R node:node "$SALTCORN_FILE_STORE" || true
      fi
    else
      echo "Creating $SALTCORN_FILE_STORE and setting ownership to node:node"
      mkdir -p "$SALTCORN_FILE_STORE"
      chown node:node "$SALTCORN_FILE_STORE" || true
    fi
  fi
  PG_WAIT_TIMEOUT=${PG_WAIT_TIMEOUT:-300}
  PG_WAIT_INTERVAL=${PG_WAIT_INTERVAL:-2}
  if [ -n "${PGHOST:-}" ] && [ -n "${PGPORT:-}" ] && [ -n "${PGUSER:-}" ]; then
    start=$(date +%s)
    until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; do
      if [ $(( $(date +%s) - $start )) -ge "$PG_WAIT_TIMEOUT" ]; then
        echo "Postgres still unreachable after ${PG_WAIT_TIMEOUT}s — exiting."
        exit 1
      fi
      echo "Waiting for Postgres at ${PGHOST}:${PGPORT}…"
      sleep "$PG_WAIT_INTERVAL"
    done
  fi
  exec gosu node saltcorn "$@"
else
  exec gosu node "$@"
fi
