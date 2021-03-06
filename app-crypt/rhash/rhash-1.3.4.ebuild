# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit toolchain-funcs multilib-minimal

DESCRIPTION="Console utility and library for computing and verifying file hash sums"
HOMEPAGE="http://rhash.anz.ru/"
SRC_URI="mirror://sourceforge/${PN}/${P}-src.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~x86 ~amd64-linux ~x64-macos ~x86-macos ~x64-solaris ~x86-solaris"
IUSE="debug nls libressl openssl static-libs"

RDEPEND="
openssl? (
	!libressl? ( dev-libs/openssl:0=[${MULTILIB_USEDEP}] )
	libressl? ( dev-libs/libressl:0=[${MULTILIB_USEDEP}] )
)"

DEPEND="${RDEPEND}
	nls? ( sys-devel/gettext )"

src_prepare() {
	default

	# Exit on test failure or src_test will always succeed.
	sed -i "s/return 1/exit 1/g" tests/test_rhash.sh || die

	# Install /etc stuff inside the Prefix
	sed -i -e 's:\$(DESTDIR)/etc:\$(DESTDIR)/$(SYSCONFDIR):g' Makefile || die

	if [[ ${CHOST} == *-darwin* ]] ; then
		local ver_script='-Wl,--version-script,exports.sym,-soname,$(SONAME)'
		local install_name='-install_name $(LIBDIR)/$(SONAME)'
		sed -i -e '/^\(SONAME\|SHAREDLIB\)/s/\.so\.\([0-9]\+\)/.\1.dylib/' \
			-e '/^SOLINK/s/\.so/.dylib/' \
			-e "s:${ver_script}:${install_name}:" \
			librhash/Makefile \
			Makefile || die
	fi

	if [[ ${CHOST} == *-solaris* ]] ; then
		# https://sourceware.org/bugzilla/show_bug.cgi?id=12548
		# skip the export.sym for now
		sed -i -e 's/,--version-script,exports.sym//' librhash/Makefile || die
	fi

	multilib_copy_sources
}

multilib_src_compile() {
	local ADDCFLAGS=(
		$(use debug || echo -DNDEBUG)
		$(use nls && echo -DUSE_GETTEXT)
		$(use openssl && echo -DOPENSSL_RUNTIME -rdynamic)
	)

	local ADDLDFLAGS=(
		$(use openssl && echo -ldl)
	)

	[[ ${CHOST} == *-darwin* || ${CHOST} == *-solaris* ]] \
		&& ADDLDFLAGS+=( $(use nls && echo -lintl) )

	emake CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" CC="$(tc-getCC)" \
		  ADDCFLAGS="${ADDCFLAGS[*]}" ADDLDFLAGS="${ADDLDFLAGS[*]}" \
		  PREFIX="${EPREFIX}"/usr LIBDIR='$(PREFIX)'/$(get_libdir) \
		  build-shared $(use static-libs && echo lib-static)
}

myemake() {
	emake DESTDIR="${D}" PREFIX="${EPREFIX}"/usr \
		LIBDIR='$(PREFIX)'/$(get_libdir) SYSCONFDIR="${EPREFIX}"/etc "${@}"
}

multilib_src_install() {
	myemake -C librhash install-lib-shared install-so-link
	multilib_is_native_abi && myemake install-shared
	use static-libs && myemake install-lib-static
}

multilib_src_install_all() {
	myemake -C librhash install-headers
	use nls && myemake install-gmo
	einstalldocs
}

multilib_src_test() {
	cd tests || die
	LD_LIBRARY_PATH=$(pwd)/../librhash ./test_rhash.sh --full ../rhash_shared || die "tests failed"
}
