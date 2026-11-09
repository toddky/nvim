#!/usr/bin/env bash
# USAGE: setup.sh
# DESCRIPTION: Check the Python dependencies of this Neovim config.

# ==============================================================================
# MAIN
# ==============================================================================
# Python remote plugins only load when Neovim's python3 provider can import pynvim.
if ! python3 -c 'import pynvim' &>/dev/null; then
	echo "ERROR: setup.sh: python3 can't import pynvim; run 'pip install pynvim' and try again" 1>&2
	exit 2
fi
