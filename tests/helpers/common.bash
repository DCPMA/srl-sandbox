# Common test helpers for srl-sandbox completion tests

MOCKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../mocks" && pwd)"
COMPLETION_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../completions" && pwd)/_srl-sandbox"

setup_mocks() {
    export PATH="$MOCKS_DIR:$PATH"
    export TMPDIR="${TMPDIR:-/tmp}"
    # Clear the call log
    rm -f "${TMPDIR}/container_calls.log"
    touch "${TMPDIR}/container_calls.log"
}

setup_sandbox_dir() {
    # Create a temporary sandbox config dir and populate with given names
    SANDBOX_DIR="$(mktemp -d)"
    mkdir -p "$SANDBOX_DIR/sandboxes"
    export MOCK_SANDBOX_DIR="$SANDBOX_DIR/sandboxes"
}

create_sandbox_json() {
    local name="$1"
    echo '{}' > "${MOCK_SANDBOX_DIR}/${name}.json"
}

teardown_sandbox_dir() {
    [[ -n "${SANDBOX_DIR:-}" ]] && rm -rf "$SANDBOX_DIR"
}
