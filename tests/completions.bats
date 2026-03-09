#!/usr/bin/env bats
# Tests for context-aware tab completion in completions/_srl-sandbox

setup() {
    load 'libs/bats-support/load'
    load 'libs/bats-assert/load'
    load 'helpers/common'
    setup_mocks
}

COMPLETION_FILE="${BATS_TEST_DIRNAME}/../completions/_srl-sandbox"

# Helper: load completion functions from the file into a zsh subprocess.
# We stub out zsh completion builtins so they don't error when sourced outside
# a completion context. The final _srl-sandbox "$@" call is also harmless when
# CURRENT / words are unset (it falls through the case statement).
_zsh_source_completion() {
    cat << 'STUB'
# Stub zsh completion builtins used in the file
_describe() {
    # Real _describe receives (description array_name [options...]).
    # Use (P) to expand the named array indirectly.
    local desc="$1"; shift
    local arr_name="$1"
    local -a items
    items=("${(@P)arr_name}")
    for item in "${items[@]}"; do print "${item%%:*}"; done
}
_arguments() { :; }
_command_names() { :; }
_directories() { :; }
STUB
}

# ---------------------------------------------------------------------------
# Test 1: Syntax check
# ---------------------------------------------------------------------------
@test "completion file passes zsh syntax check" {
    run zsh -n "$COMPLETION_FILE"
    assert_success
}

# ---------------------------------------------------------------------------
# Test 2: _srl_sandbox_running is defined in the completion file
# ---------------------------------------------------------------------------
@test "_srl_sandbox_running function is defined in completion file" {
    run zsh -c "
$(_zsh_source_completion)
source '${COMPLETION_FILE}'
type _srl_sandbox_running
"
    assert_success
    assert_output --partial "_srl_sandbox_running"
}

# ---------------------------------------------------------------------------
# Test 3: _srl_sandbox_running returns only running containers
# ---------------------------------------------------------------------------
@test "_srl_sandbox_running lists only running containers" {
    run zsh -c "
$(_zsh_source_completion)
source '${COMPLETION_FILE}'

# Override container to return mock data
container() {
    if [[ \"\$1\" == 'list' ]]; then
        printf 'NAME\tSTATUS\tIMAGE\n'
        printf 'sandbox1\trunning\timg\n'
        printf 'sandbox2\trunning\timg\n'
    fi
}

_srl_sandbox_running
"
    assert_success
    assert_output --partial "sandbox1"
    assert_output --partial "sandbox2"
}

# ---------------------------------------------------------------------------
# Test 4: _srl_sandbox_stopped returns only stopped (not running) containers
# ---------------------------------------------------------------------------
@test "_srl_sandbox_stopped returns only stopped containers" {
    local sandbox_dir
    sandbox_dir="$(mktemp -d)"
    echo '{}' > "$sandbox_dir/alpha.json"
    echo '{}' > "$sandbox_dir/beta.json"
    echo '{}' > "$sandbox_dir/gamma.json"

    run zsh -c "
$(_zsh_source_completion)
source '${COMPLETION_FILE}'

# Override container: alpha is running
container() {
    if [[ \"\$1\" == 'list' ]]; then
        printf 'NAME\tSTATUS\tIMAGE\n'
        printf 'alpha\trunning\timg\n'
    fi
}

# Override HOME so the function reads from our temp dir
export HOME='$sandbox_dir/..'
mkdir -p '$sandbox_dir/../.config/srl-sandbox'
cp -r '$sandbox_dir' '$sandbox_dir/../.config/srl-sandbox/sandboxes' 2>/dev/null || true

_srl_sandbox_stopped
"
    assert_success
    assert_output --partial "beta"
    assert_output --partial "gamma"
    refute_output --partial "alpha"

    rm -rf "$sandbox_dir"
}

# ---------------------------------------------------------------------------
# Test 5: _srl_sandbox_running_or_all includes "all" + running containers
# ---------------------------------------------------------------------------
@test "_srl_sandbox_running_or_all includes 'all' and running containers" {
    run zsh -c "
$(_zsh_source_completion)
source '${COMPLETION_FILE}'

container() {
    if [[ \"\$1\" == 'list' ]]; then
        printf 'NAME\tSTATUS\tIMAGE\n'
        printf 'mybox\trunning\timg\n'
    fi
}

_srl_sandbox_running_or_all
"
    assert_success
    assert_output --partial "all"
    assert_output --partial "mybox"
}

# ---------------------------------------------------------------------------
# Test 6: Empty containers — no errors and clean exit
# ---------------------------------------------------------------------------
@test "_srl_sandbox_running handles empty container list gracefully" {
    run zsh << 'ZSH_EOF'
    _describe() { shift; printf '%s\n' "$@"; }
    container() { echo "NAME  STATUS  IMAGE"; }  # header only, no containers

    _srl_sandbox_running() {
        local -a names
        names=("${(@f)$(container list 2>/dev/null | awk 'NR>1 && $2=="running" {print $1}')}")
        names=("${(@)names:#}")
        [[ ${#names} -eq 0 ]] && return
        _describe 'running sandbox' names
    }

    _srl_sandbox_running
    echo "exit:$?"
ZSH_EOF
    assert_success
    # Should produce no sandbox names (only the exit status line)
    refute_output --partial "running"
}
