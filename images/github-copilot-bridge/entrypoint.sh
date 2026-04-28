#!/usr/bin/env bash

set -euo pipefail

COPILOT_BIN=/usr/local/bin/copilot
MAX_RETRIES="${MAX_RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-5}"
COPILOT_PORT="${COPILOT_PORT:-8001}"
COPILOT_PROXY_PORT="${COPILOT_PROXY_PORT:-8000}"

if [[ -n "${COPILOT_GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
    export GH_TOKEN="${COPILOT_GITHUB_TOKEN}"
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
    echo "No GitHub token configured. Set COPILOT_GITHUB_TOKEN or GH_TOKEN."
    exit 1
fi

cleanup() {
    if [[ -n "${COPILOT_PID:-}" ]]; then
        kill "${COPILOT_PID}" 2>/dev/null || true
    fi
    if [[ -n "${SOCAT_PID:-}" ]]; then
        kill "${SOCAT_PID}" 2>/dev/null || true
    fi
}

terminate() {
    cleanup
    wait 2>/dev/null || true
    exit 143
}

trap terminate INT TERM
trap cleanup EXIT

echo "Verifying GitHub Copilot CLI authentication..."
if timeout 10 "${COPILOT_BIN}" -p "auth status" --silent >/dev/null 2>&1 || timeout 10 "${COPILOT_BIN}" auth status >/dev/null 2>&1; then
    echo "Authentication probe completed."
else
    echo "Copilot CLI auth probe failed. Proceeding anyway."
fi

COPILOT_HELP=$("${COPILOT_BIN}" --help 2>&1 || true)
COPILOT_HEADLESS_HELP=$("${COPILOT_BIN}" --headless --help 2>&1 || true)

has_flag() {
    local help_text="$1"
    local flag="$2"
    printf '%s\n' "$help_text" | grep -qE "^[[:space:]]*--${flag}([[:space:]=]|$)"
}

set -- --headless --port "${COPILOT_PORT}"
if has_flag "${COPILOT_HELP}" no-auto-update; then
    set -- "$@" --no-auto-update
fi
if has_flag "${COPILOT_HELP}" log-level; then
    set -- "$@" --log-level info
fi

echo "Starting proxy on port ${COPILOT_PROXY_PORT} -> 127.0.0.1:${COPILOT_PORT}..."
socat "TCP-LISTEN:${COPILOT_PROXY_PORT},fork,bind=0.0.0.0,reuseaddr" "TCP:127.0.0.1:${COPILOT_PORT}" &
SOCAT_PID=$!

attempt=1
while true; do
    echo "Starting GitHub Copilot CLI server on port ${COPILOT_PORT} (attempt ${attempt})..."
    "${COPILOT_BIN}" "$@" &
    COPILOT_PID=$!
    wait "${COPILOT_PID}"
    exit_code=$?
    COPILOT_PID=""

    if [[ "${exit_code}" -eq 0 ]]; then
        echo "GitHub Copilot CLI server exited normally. Stopping bridge."
        exit 0
    fi

    if [[ "${attempt}" -ge "${MAX_RETRIES}" ]]; then
        echo "GitHub Copilot CLI server failed after ${MAX_RETRIES} attempts (last exit code: ${exit_code})."
        exit "${exit_code}"
    fi

    echo "GitHub Copilot CLI server exited with code ${exit_code}. Retrying in ${RETRY_DELAY} seconds..."
    sleep "${RETRY_DELAY}"
    attempt=$((attempt + 1))
done
