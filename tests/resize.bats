#!/usr/bin/env bats
# Tests for cmd_resize in srl-sandbox

load "helpers/common"

setup() {
    setup_sandbox_env
}

teardown() {
    teardown_sandbox_env
}

# Helper: get all logged container calls
_container_calls() {
    cat "${CONTAINER_CALLS_LOG}" 2>/dev/null || true
}

# Helper: assert a particular call appears in the log
_assert_call() {
    grep -qF "$1" "${CONTAINER_CALLS_LOG}" \
        || (echo "Expected call not found: $1"; echo "Actual calls:"; cat "${CONTAINER_CALLS_LOG}"; return 1)
}

# ── Test 1: resize running container with --mem ──────────────────────────────
@test "resize running container --mem 8 stops then recreates with --memory 8G" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        # Stub confirm_default_yes to auto-confirm
        confirm_default_yes() { return 0; }
        cmd_resize mybox --mem 8
    "

    assert_success

    # container stop mybox should be called
    _assert_call "container stop mybox"

    # container rm mybox should be called
    _assert_call "container rm mybox"

    # container run should include --memory 8G
    grep -qF -- "--memory 8G" "${CONTAINER_CALLS_LOG}" \
        || (echo "Expected --memory 8G in container run call"; cat "${CONTAINER_CALLS_LOG}"; return 1)
}

# ── Test 2: resize running container with --cpus ──────────────────────────────
@test "resize running container --cpus 4 recreates with --cpus 4" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize mybox --cpus 4
    "

    assert_success

    _assert_call "container stop mybox"
    grep -qF -- "--cpus 4" "${CONTAINER_CALLS_LOG}" \
        || (echo "Expected --cpus 4 in container run call"; cat "${CONTAINER_CALLS_LOG}"; return 1)
}

# ── Test 3: resize with both --mem and --cpus ────────────────────────────────
@test "resize running container --mem 8 --cpus 4 combines both flags" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize mybox --mem 8 --cpus 4
    "

    assert_success

    _assert_call "container stop mybox"
    grep -qF -- "--memory 8G" "${CONTAINER_CALLS_LOG}" \
        || (echo "Expected --memory 8G"; cat "${CONTAINER_CALLS_LOG}"; return 1)
    grep -qF -- "--cpus 4" "${CONTAINER_CALLS_LOG}" \
        || (echo "Expected --cpus 4"; cat "${CONTAINER_CALLS_LOG}"; return 1)
}

# ── Test 4: resize nonexistent sandbox exits 1 ──────────────────────────────
@test "resize nonexistent sandbox exits 1 with error message" {
    export MOCK_RUNNING_CONTAINERS=""
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize nonexistent --mem 8
    "

    assert_failure
    assert_output --partial "not found"
}

# ── Test 5: resize --mem 0 is rejected ──────────────────────────────────────
@test "resize --mem 0 exits 1 with validation error" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize mybox --mem 0
    "

    assert_failure
    assert_output --partial "0"
}

# ── Test 6: resize stopped container (no stop needed) ───────────────────────
@test "resize stopped container does not call stop, still recreates" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS=""
    export MOCK_STOPPED_CONTAINERS="mybox"

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize mybox --mem 8
    "

    assert_success

    # Should NOT have called stop
    if grep -qF "container stop mybox" "${CONTAINER_CALLS_LOG}" 2>/dev/null; then
        echo "ERROR: container stop should not be called for stopped container"
        cat "${CONTAINER_CALLS_LOG}"
        return 1
    fi

    # Should still recreate
    grep -qF -- "--memory 8G" "${CONTAINER_CALLS_LOG}" \
        || (echo "Expected --memory 8G in container run call"; cat "${CONTAINER_CALLS_LOG}"; return 1)
}

# ── Test 7: state JSON is updated after resize ───────────────────────────────
@test "resize saves updated mem and cpus to state JSON" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize mybox --mem 8 --cpus 4
    "

    assert_success

    local new_mem
    new_mem=$(read_state "mybox" "mem")
    [ "$new_mem" = "8" ] || (echo "Expected mem=8, got $new_mem"; return 1)

    local new_cpus
    new_cpus=$(read_state "mybox" "cpus")
    [ "$new_cpus" = "4" ] || (echo "Expected cpus=4, got $new_cpus"; return 1)
}

# ── Test 8: cancelling confirmation aborts resize ───────────────────────────
@test "resize cancelled by user does not stop or recreate container" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        # Stub confirm_default_yes to decline
        confirm_default_yes() { return 1; }
        cmd_resize mybox --mem 8
    "

    assert_success

    # No stop or run should have been called
    if grep -qF "container stop" "${CONTAINER_CALLS_LOG}" 2>/dev/null; then
        echo "ERROR: container stop should not be called when user cancels"
        cat "${CONTAINER_CALLS_LOG}"
        return 1
    fi
    if grep -qF "container run" "${CONTAINER_CALLS_LOG}" 2>/dev/null; then
        echo "ERROR: container run should not be called when user cancels"
        cat "${CONTAINER_CALLS_LOG}"
        return 1
    fi
}

# ── Test 9: multiple extra mounts are each passed as --volume ────────────────
@test "resize re-adds multiple comma-separated extra mounts as individual --volume flags" {
    # Write state with two extra mounts stored as comma-separated string
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp" "/host/data:/mnt/data,/host/logs:/mnt/logs"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize mybox --mem 8
    "

    assert_success

    # Each mount should appear as a separate --volume flag in the container run call
    grep -qF -- "--volume /host/data:/mnt/data" "${CONTAINER_CALLS_LOG}" \
        || (echo "Expected --volume /host/data:/mnt/data"; cat "${CONTAINER_CALLS_LOG}"; return 1)
    grep -qF -- "--volume /host/logs:/mnt/logs" "${CONTAINER_CALLS_LOG}" \
        || (echo "Expected --volume /host/logs:/mnt/logs"; cat "${CONTAINER_CALLS_LOG}"; return 1)
}

# ── Test 10: no-op resize (no flags) exits with error ───────────────────────
@test "resize with no --mem or --cpus flags exits with error" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize mybox
    "

    assert_failure
    assert_output --partial "Specify at least"
}

# ── Test 11: cmd_sync_internal called after container recreation ──────────────
@test "resize calls cmd_sync_internal after recreating container" {
    write_state "mybox" 2 4 "/proj/myapp" "/home/dev/myapp"

    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    local sync_log="${TEST_TMPDIR}/sync_calls.log"

    _run_zsh "
        confirm_default_yes() { return 0; }
        wait_container_ssh() { return 0; }
        cmd_sync_internal() { echo \"synced:\${1}\" >> '${sync_log}'; }
        cmd_resize mybox --mem 8
    "

    assert_success
    run grep -c 'synced:mybox' "${sync_log}"
    assert_output "1"
}

# ── Test 12: missing state file exits with helpful error ─────────────────────
@test "resize exits with error when state file is missing" {
    # container_exists check needs the container to be visible, but no state file written
    export MOCK_RUNNING_CONTAINERS="mybox"
    export MOCK_STOPPED_CONTAINERS=""

    _run_zsh "
        confirm_default_yes() { return 0; }
        cmd_resize mybox --mem 8
    "

    assert_failure
    assert_output --partial "State file"
}
