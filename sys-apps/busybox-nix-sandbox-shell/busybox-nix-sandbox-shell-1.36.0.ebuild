# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit edo toolchain-funcs

DESCRIPTION="static busybox for sys-apps/nix sandbox needs"
HOMEPAGE="https://www.busybox.net/"
MY_P=busybox-${PV/_/-}
SRC_URI="https://www.busybox.net/downloads/${MY_P}.tar.bz2"
KEYWORDS="~amd64 ~x86"

LICENSE="GPL-2"
SLOT="0"
# llvm-libunwind enables a hack to supply missing symbols for static
# glibc linking.
IUSE="llvm-libunwind"

DEPEND=">=sys-kernel/linux-headers-2.6.39
	elibc_glibc? ( sys-libs/glibc[static-libs(+)] )
	virtual/libcrypt[static-libs]"
RDEPEND=""

PATCHES=("${FILESDIR}"/busybox-1.35.0-longer-lines.patch)

S=${WORKDIR}/${MY_P}

busybox_set_config() {
	local k=$1 v=$2
	case "${v}" in
		y) sed -i .config -e "s|.*\<CONFIG_${k}\>.*|CONFIG_${k}=y|" || die ;;
		n) sed -i .config -e "s|.*\<CONFIG_${k}\>.*|# CONFIG_${k} is unset|" || die ;;
		*) sed -i .config -e "s|.*\<CONFIG_${k}\>.*|CONFIG_${k}=${v}|" || die ;;
	esac
}

_emake() {
	emake HOSTCC="$(tc-getBUILD_CC)" CC="$(tc-getCC)" "$@"
}

src_prepare() {
	default

	if use llvm-libunwind; then
		# Today's llvm's runtime library does not implement
		# small subset of libgcc.a / libgcc_s.so for TF (long
		# double) types.
		# TODO: remove once implemented upstream (or when glibc
		# knows how to avoid their use).
		einfo "Checking for libc.a static linkage."
		if ! $(tc-getCC) -static ${CFLAGS} ${LDFLAGS} "${FILESDIR}"/printf-probe.c -o "${T}"/printf-probe.elf; then
			einfo "Enabling 'long double' TF hack."
			mkdir "${T}"/tfhack || die

			pushd "${T}"/tfhack || die
			edo $(tc-getCC) -c -fPIC ${CFLAGS} "${FILESDIR}"/libgcc-TF-stubs.c -o libgcc-TF-stubs.o
			edo $(tc-getAR) qc libtfhack.a libgcc-TF-stubs.o
			edo $(tc-getRANLIB) libtfhack.a
			popd

			# TODO: it's not cross-compiler friendly.
			LDFLAGS="${LDFLAGS} -L${T}/tfhack -ltfhack"
			einfo "Mangle LDFLAGS: ${LDFLAGS}"
		fi
	fi

}

src_configure() {
	# Why not use Gentoo's default busybox package:
	#
	# 1. We stick to nixpkg's options:
	#     https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/busybox/sandbox-shell.nix
	#     https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/busybox/default.nix
	# as some packages actually fail on /bin/sh providing builtins:
	# - systemd can't handle busibox's ar: https://github.com/trofi/nix-guix-gentoo/issues/3
	#
	# 2. We provide always-static version of busybox so it could be used in a chroot.

	# minimal config
	_emake allnoconfig

	busybox_set_config FEATURE_FANCY_ECHO y
	busybox_set_config FEATURE_SH_MATH y
	busybox_set_config FEATURE_SH_MATH_64 y
	busybox_set_config ASH y
	busybox_set_config ASH_OPTIMIZE_FOR_SIZE y
	busybox_set_config ASH_ALIAS y
	busybox_set_config ASH_BASH_COMPAT y
	busybox_set_config ASH_CMDCMD y
	busybox_set_config ASH_ECHO y
	busybox_set_config ASH_GETOPTS y
	busybox_set_config ASH_INTERNAL_GLOB y
	busybox_set_config ASH_JOB_CONTROL y
	busybox_set_config ASH_PRINTF y
	busybox_set_config ASH_TEST y

	busybox_set_config INSTALL_NO_USR y
	busybox_set_config LFS y
	busybox_set_config STATIC y
	busybox_set_config FEATURE_MOUNT_CIFS n
	busybox_set_config FEATURE_COPYBUF_KB 64
	busybox_set_config CROSS_COMPILER_PREFIX "\"${CHOST}-\""
	busybox_set_config EXTRA_CFLAGS "\"${CFLAGS}\""
	busybox_set_config EXTRA_LDFLAGS "\"${LDFLAGS}\""

	# Workaround for external dependencies:
	#    https://github.com/trofi/nix-guix-gentoo/issues/5
	# We need to execute exactly this script in busybox environment:
	# ```sh
	#   mkdir $out
	#   cd $out
	#   tar xf $src
	#   if [ * != $channelName ]; then
	#     mv * $out/$channelName
	#   fi
	# ```
	busybox_set_config FEATURE_SH_STANDALONE y # enable busybox builtins instead of externals
	busybox_set_config   MKDIR y
	busybox_set_config   MV y
	busybox_set_config   TAR y
	busybox_set_config     FEATURE_TAR_GNU_EXTENSIONS y
	busybox_set_config     FEATURE_TAR_UNAME_GNAME y # user/group
	busybox_set_config     FEATURE_TAR_AUTODETECT y # we don't specify unpacker type
	busybox_set_config     FEATURE_SEAMLESS_XZ y # currently used by nix
	busybox_set_config     FEATURE_SEAMLESS_BZ2 y
	busybox_set_config     FEATURE_SEAMLESS_GZ y

	# sharutils's test suite uses /bin/sh and needs 'tar cf' to work
	busybox_set_config FEATURE_TAR_CREATE y
}

src_compile() {
	_emake busybox SKIP_STRIP=y V=1
}

src_test() {
	_emake check
}

src_install() {
	# avoid installing any symlinks
	newbin busybox busybox-nix-sandbox-shell
}
