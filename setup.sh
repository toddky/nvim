#!/usr/bin/env bash
declare -r CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

if ! python3 -c 'import pynvim'; then
	echo "Run 'pip install pynvim' and try again"
	exit 2
fi

