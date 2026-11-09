#!/usr/bin/env bash
# USAGE: install.sh
# DESCRIPTION: Build and install Neovim from source on Debian/Ubuntu.

# ==============================================================================
# ENVIRONMENT
# ==============================================================================
nvim_version=0.10.4
tarball_url="https://github.com/neovim/neovim/releases/download/v${nvim_version}/neovim-${nvim_version}.tar.gz"


# ==============================================================================
# HELPERS
# ==============================================================================
function error() {
	echo "ERROR: $*" 1>&2
	exit 1
}


# ==============================================================================
# CHECK VERSION
# ==============================================================================
if [[ "$(nvim --version 2>/dev/null | head -1)" == "NVIM v${nvim_version}" ]]; then
	echo "nvim ${nvim_version} is already installed"
	exit 0
fi


# ==============================================================================
# INSTALL DEPENDENCIES
# ==============================================================================
apt_packages=()
apt_packages+=(build-essential cmake gettext)
if ! sudo apt install -y "${apt_packages[@]}"; then
	error "apt install failed; check sudo access and that this is a Debian/Ubuntu host"
fi


# ==============================================================================
# DOWNLOAD
# ==============================================================================
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

tarball_file="$build_dir/nvim-${nvim_version}.tar.gz"
if ! curl -fLo "$tarball_file" "$tarball_url"; then
	error "cannot download $tarball_url"
fi
if ! tar -xzf "$tarball_file" -C "$build_dir"; then
	error "cannot extract $tarball_file"
fi
source_dir="$build_dir/neovim-${nvim_version}"


# ==============================================================================
# BUILD
# ==============================================================================
if ! make -C "$source_dir" CMAKE_BUILD_TYPE=Release; then
	error "Neovim build failed in $source_dir"
fi


# ==============================================================================
# INSTALL
# ==============================================================================
if ! sudo make -C "$source_dir" install; then
	error "make install failed"
fi

echo "Installed $(nvim --version | head -1)"
