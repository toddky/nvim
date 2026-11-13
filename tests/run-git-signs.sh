#!/usr/bin/env bash
# USAGE: tests/run-git-signs.sh
# DESCRIPTION: Run the git-signs regression tests headless with this config, then check startup without git on PATH.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================================================================
# ENVIRONMENT
# ==============================================================================
# ~/.local/bin/nvim may be a wrapper script that needs bash on PATH; the no-git check needs the real binary.
nvim_binary="$(nvim --headless -c 'lua io.stdout:write(vim.v.progpath)' -c 'qa!' 2>/dev/null)"
if [[ ! -x "$nvim_binary" ]]; then
	echo "ERROR: run-git-signs.sh: cannot find the nvim binary; check that nvim is on PATH" 1>&2
	exit 1
fi


# ==============================================================================
# REGRESSION TESTS
# ==============================================================================
# A Lua error stops luafile before the final qa!, so cquit makes the run fail instead of hanging.
test_args=()
test_args+=(--headless)
test_args+=(-c "luafile $SCRIPT_DIR/git-signs.lua")
test_args+=(-c 'cquit 1')
timeout 600 "$nvim_binary" "${test_args[@]}" 2>&1 | tr -d '\r' | grep -a -o -E '(PASS|FAIL) .*|[0-9]+ passed, [0-9]+ failed|E[0-9]+:.*|.*[Ee]rror.*'
exit_code="${PIPESTATUS[0]}"
if ((exit_code == 124)); then
	echo "FAIL regression tests timed out after 600 s"
fi


# ==============================================================================
# NO GIT
# ==============================================================================
# A plain text file, so no language server starts; those need a PATH of their own.
empty_bin_dir="$(mktemp -d)"
trap 'rm -rf "$empty_bin_dir"' EXIT
echo 'plain text' > "$empty_bin_dir/plain.txt"
no_git_output="$(PATH="$empty_bin_dir" "$nvim_binary" --headless -c 'lua io.stdout:write("STARTED " .. vim.fn.execute("messages"))' -c 'qa!' "$empty_bin_dir/plain.txt" 2>&1)"
if [[ "$no_git_output" != *STARTED* ]]; then
	echo "FAIL no git on PATH: nvim did not start: $no_git_output"
	exit_code=1
elif grep -a -q -i -E 'error|git-signs' <<<"$no_git_output"; then
	echo "FAIL no git on PATH: $no_git_output"
	exit_code=1
else
	echo "PASS no git on PATH: nvim started with no errors"
fi
exit "$exit_code"
