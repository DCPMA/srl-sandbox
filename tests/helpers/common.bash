#!/usr/bin/env bash
# Common test helpers for srl-sandbox tests

# Load bats libraries — BATS_TEST_DIRNAME is the dir of the calling .bats file
# When loaded from tests/*.bats, BATS_TEST_DIRNAME is tests/
load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"

# Directory containing test files
# When loaded from tests/*.bats, BATS_TEST_DIRNAME is tests/
TESTS_DIR="${BATS_TEST_DIRNAME}"
SANDBOX_SCRIPT="${TESTS_DIR}/../srl-sandbox"
MOCKS_DIR="${TESTS_DIR}/mocks"

# Minimal PATH for subshell: mocks dir + standard system paths
SYSTEM_PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

setup_sandbox_env() {
    # Create temp dir for this test
    export TEST_TMPDIR
    TEST_TMPDIR="$(mktemp -d)"

    # Create a fake ZDOTDIR so zsh doesn't load the real user's dotfiles
    export FAKE_ZSH_DIR="${TEST_TMPDIR}/zshconf"
    mkdir -p "${FAKE_ZSH_DIR}"
    # Create empty .zshenv/.zshrc so zsh loads cleanly
    touch "${FAKE_ZSH_DIR}/.zshenv"
    touch "${FAKE_ZSH_DIR}/.zshrc"

    # Override HOME so SANDBOXES_DIR resolves inside TEST_TMPDIR
    export REAL_HOME="$HOME"
    export HOME="${TEST_TMPDIR}/home"
    mkdir -p "${HOME}/.config/srl-sandbox/sandboxes"
    mkdir -p "${HOME}/.ssh"
    mkdir -p "${HOME}/.claude"
    touch "${HOME}/.claude.json"
    mkdir -p "${HOME}/.aws"

    export CONTAINER_CALLS_LOG="${TEST_TMPDIR}/container_calls.log"
    touch "${CONTAINER_CALLS_LOG}"
}

teardown_sandbox_env() {
    export HOME="${REAL_HOME:-$HOME}"
    rm -rf "${TEST_TMPDIR}"
}

# Run a zsh snippet that sources srl-sandbox without executing main()
# Uses ZDOTDIR to avoid loading user's .zshenv and sets a clean minimal PATH
_run_zsh() {
    local code="$1"
    local test_path="${MOCKS_DIR}:${SYSTEM_PATH}"
    run env \
        ZDOTDIR="${FAKE_ZSH_DIR}" \
        HOME="${HOME}" \
        PATH="${test_path}" \
        CONTAINER_CALLS_LOG="${CONTAINER_CALLS_LOG}" \
        MOCK_RUNNING_CONTAINERS="${MOCK_RUNNING_CONTAINERS:-}" \
        MOCK_STOPPED_CONTAINERS="${MOCK_STOPPED_CONTAINERS:-}" \
        BATS_TEST_SOURCING=1 \
        zsh -c "source '${SANDBOX_SCRIPT}'; ${code}"
}

# Write a minimal state JSON for a sandbox into the fake HOME
write_state() {
    local name="$1"
    local cpus="${2:-2}"
    local mem="${3:-4}"
    local proj_path="${4:-/home/dev/project}"
    local guest_project="${5:-/home/dev/project}"
    local state_file="${HOME}/.config/srl-sandbox/sandboxes/${name}.json"
    python3 - <<PYEOF
import json
d = {
    "name": "${name}",
    "project_path": "${proj_path}",
    "guest_project": "${guest_project}",
    "cpus": ${cpus},
    "mem": ${mem},
    "extra_mounts": "",
    "created": "2026-03-09T00:00:00Z"
}
json.dump(d, open("${state_file}", "w"), indent=2)
PYEOF
}

# Read a value from the saved state JSON for assertions
read_state() {
    local name="$1"
    local key="$2"
    local state_file="${HOME}/.config/srl-sandbox/sandboxes/${name}.json"
    python3 -c "import json; d=json.load(open('${state_file}')); print(d.get('${key}',''))"
}
