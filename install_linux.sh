#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/api"
VENV_DIR="$API_DIR/.venv"
DEVICE_PORT=""
HTTP_HOST="127.0.0.1"
HTTP_PORT="5000"
FLASH=1
RUN=1

usage() {
    cat <<'EOF'
Usage: ./install_linux.sh [options]

Set up the dashboard's Python environment, install PlatformIO, optionally
flash a connected Wemos D1 mini, then run the dashboard.

Options:
  --device-port PORT  Serial port to flash, e.g. /dev/ttyUSB0
  --no-flash          Do not build or flash firmware
  --no-run            Install only; do not start the dashboard
  --host HOST         Dashboard bind address (default: 127.0.0.1)
  --http-port PORT    Dashboard port (default: 5000)
  -h, --help          Show this help

If --device-port is omitted, the installer asks before flashing a single
detected CH340/WCH device under /dev/serial/by-id. Otherwise flashing is
skipped; use --device-port to select the Wemos explicitly.
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --device-port)
            (($# >= 2)) || fail "--device-port requires a serial port"
            DEVICE_PORT="$2"
            shift 2
            ;;
        --no-flash)
            FLASH=0
            shift
            ;;
        --no-run)
            RUN=0
            shift
            ;;
        --host)
            (($# >= 2)) || fail "--host requires an address"
            HTTP_HOST="$2"
            shift 2
            ;;
        --http-port)
            (($# >= 2)) || fail "--http-port requires a port"
            HTTP_PORT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option: $1 (use --help for usage)"
            ;;
    esac
done

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    fail "do not run this installer as root; use your regular user account"
fi

PYTHON="$(command -v python3 || true)"
[[ -n "$PYTHON" ]] || fail "python3 not found. Install Python 3 and its venv support first."
"$PYTHON" -c 'import sys; sys.version_info >= (3, 8) or sys.exit(1)' \
    || fail "Python 3.8 or newer is required."

if [[ ! -d "$VENV_DIR" ]]; then
    "$PYTHON" -m venv "$VENV_DIR" \
        || fail "could not create the virtual environment; install python3-venv and retry"
fi

VENV_PYTHON="$VENV_DIR/bin/python"
VENV_PIO="$VENV_DIR/bin/pio"
"$VENV_PYTHON" -m pip install --upgrade pip
"$VENV_PYTHON" -m pip install -r "$API_DIR/requirements.txt"

if ((FLASH)); then
    "$VENV_PYTHON" -m pip install platformio

    if [[ -z "$DEVICE_PORT" ]]; then
        mapfile -t WEMOS_PORTS < <(
            find /dev/serial/by-id -maxdepth 1 -type l \
                \( -iname '*1a86*' -o -iname '*ch340*' -o -iname '*wch*' \) \
                -print 2>/dev/null | sort
        )
        if ((${#WEMOS_PORTS[@]} == 1)); then
            DETECTED_PORT="${WEMOS_PORTS[0]}"
            printf 'Detected CH340/WCH USB serial device: %s\n' "$DETECTED_PORT"
            if [[ -t 0 ]]; then
                read -r -p "Flash Wemos firmware to this device? [y/N] " CONFIRM_FLASH
                case "$CONFIRM_FLASH" in
                    y|Y|yes|YES) DEVICE_PORT="$DETECTED_PORT" ;;
                    *) printf 'Skipping firmware flash.\n' ;;
                esac
            else
                printf 'Not flashing automatically in non-interactive mode; use --device-port to select it.\n'
            fi
        elif ((${#WEMOS_PORTS[@]} > 1)); then
            printf 'Multiple CH340/WCH serial devices found; not guessing which one to flash:\n' >&2
            printf '  %s\n' "${WEMOS_PORTS[@]}" >&2
            printf 'Re-run with --device-port /dev/serial/by-id/DEVICE\n' >&2
        fi
    fi

    if [[ -n "$DEVICE_PORT" ]]; then
        [[ -e "$DEVICE_PORT" ]] || fail "serial port not found: $DEVICE_PORT"
        if [[ ! -r "$DEVICE_PORT" || ! -w "$DEVICE_PORT" ]]; then
            printf 'No read/write access to %s.\n' "$DEVICE_PORT" >&2
            printf 'On Debian/Ubuntu, run: sudo usermod -aG dialout %s\n' "$USER" >&2
            printf 'Then log out and back in, reconnect the board, and rerun this script.\n' >&2
            exit 1
        fi

        "$VENV_PIO" run -d "$ROOT_DIR" -e d1_mini -t upload \
            --upload-port "$DEVICE_PORT"
    else
        printf 'No Wemos serial port selected; skipping firmware flash.\n'
        printf 'Connect the board and rerun with --device-port /dev/ttyUSB0 to flash it.\n'
    fi
fi

if ((RUN)); then
    printf '\nDashboard: http://localhost:%s\n' "$HTTP_PORT"
    printf 'Select the Wemos serial port in the Sniffer list and click Connect.\n'
    printf 'Press Ctrl+C to stop the dashboard.\n\n'
    cd "$API_DIR"
    FLOCKYOU_HOST="$HTTP_HOST" FLOCKYOU_PORT="$HTTP_PORT" \
        "$VENV_PYTHON" "$API_DIR/flockyou.py"
else
    printf '\nInstall complete. Start the dashboard with:\n'
    printf '  cd %q && %q flockyou.py\n' "$API_DIR" "$VENV_PYTHON"
fi
