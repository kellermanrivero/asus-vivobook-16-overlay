# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )

inherit edo meson python-any-r1

DESCRIPTION="Complex camera support library"
HOMEPAGE="https://libcamera.org"
SRC_URI="https://gitlab.freedesktop.org/camera/libcamera/-/archive/v${PV}/libcamera-v${PV}.tar.bz2 -> ${P}.tar.bz2"
S="${WORKDIR}/libcamera-v${PV}"

LICENSE="Apache-2.0 CC0-1.0 BSD BSD-2 CC-BY-4.0 CC-BY-SA-4.0 GPL-2+ GPL-2 LGPL-2.1+ MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="drm elfutils gstreamer gui +ipa-signing jpeg openssl sdl test tiff tools trace +udev unwind v4l"
RESTRICT="
	!test? ( test )
	ipa-signing? ( bindist )
"
REQUIRED_USE="
	sdl? ( gui )
	test? ( udev )
"

# 'dev-cpp/gtest' is required as runtime dependency because it's used by lc-compliance tool
COMMON_DEPEND="
	dev-libs/libyaml
	elfutils? ( dev-libs/elfutils )
	gstreamer? (
		dev-libs/glib:2
		>=media-libs/gstreamer-1.14.0:1.0
		>=media-libs/gst-plugins-base-1.14:1.0
	)
	!openssl? ( net-libs/gnutls:= )
	openssl? ( dev-libs/openssl:= )
	tools? (
		dev-cpp/gtest:=
		dev-libs/libevent:=
		drm? ( x11-libs/libdrm )
		gui? (
			dev-qt/qtbase:6[gui,opengl,widgets]
			sdl? (
				media-libs/libsdl2
				jpeg? ( media-libs/libjpeg-turbo:= )
			)
		)
		tiff? ( media-libs/tiff:= )
	)
	trace? (
		dev-util/lttng-ust:=
	)
	udev? ( virtual/libudev:= )
	unwind? ( sys-libs/libunwind:= )
"

DEPEND="
	${COMMON_DEPEND}
	test? ( media-libs/libyuv:= )
"

RDEPEND="
	${COMMON_DEPEND}
"

BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep '
		dev-python/jinja2[${PYTHON_USEDEP}]
		dev-python/ply[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
	')
"

PATCHES=(
	"${FILESDIR}"/${PN}-no-automagic-flags.patch
)

python_check_deps() {
	python_has_version "dev-python/jinja2[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/ply[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/pyyaml[${PYTHON_USEDEP}]"
}

src_configure() {
	local emesonargs=(
		# Broken for >=dev-python/sphinx-7
		# $(meson_feature doc documentation)
		-Ddocumentation=disabled
		# TODO: Python bindings are disabled for now since they are experimental
		-Dpycamera=disabled
		# TODO: Skipping 'rpi/pisp' and 'virtual' pipelines.
		# 	- Pipeline 'rpi/pisp' depends on libpisp not available in Gentoo repository yet.
		# 	- Pipeline 'virtual' depends on libyuv but seems to be only used during tests.
		-Dpipelines=imx8-isi,ipu3,mali-c55,rkisp1,rpi/vc4,simple,uvcvideo,vimc
		$(meson_feature tools cam)
		$(meson_feature tools lc-compliance)
		$(meson_feature drm cam-drm-sink)
		$(meson_feature sdl cam-sdl-sink)
		$(meson_feature jpeg cam-sdl-jpeg)
		$(meson_feature tiff tiff)
		$(meson_feature gstreamer)
		$(meson_feature !openssl gnutls)
		$(meson_feature trace tracing)
		$(meson_feature unwind libunwind)
		$(meson_feature elfutils libdw)
		$(meson_feature udev)
		$(meson_feature v4l v4l2)
		$(meson_use test)
	)

	# QCam requires both tools & gui USE flags to be enabled
	if use tools && use gui; then
		emesonargs+=(
			-Dqcam=enabled
		)
	else
		emesonargs+=(
			-Dqcam=disabled
		)
	fi

	meson_src_configure
}

src_install() {
	meson_src_install

	# Prepare scripts used for IPA module signing.
	# After stripping IPA binaries, they need to be signed again.
	if use ipa-signing; then
		einfo "IPA module signing is enabled. Copying miscellanous files into temporal location"
		mkdir -p "${T}"/signing-scripts
		cp -v "${S}"/src/ipa/ipa-sign{,-install}.sh \
				"${BUILD_DIR}"/src/apps/ipa-verify/ipa_verify \
				"${BUILD_DIR}"/src/ipa-priv-key.pem \
				"${T}"/signing-scripts
	else
		ewarn "IPA module signing is disabled. This may lead to unnecessary overhead"
	fi
}

pkg_preinst() {
	# IPA modules must be resigned after the strip-process, then verified
	if use ipa-signing; then
		local mods=()
		mapfile -t -d '' mods < <(find -H "${ED}"/usr/$(get_libdir)/libcamera/ipa/ -type f -name '*.so' -print0)
		pushd "${T}"/signing-scripts || die
		edob -m "Regenerating IPA modules signatures" ./ipa-sign-install.sh ./ipa-priv-key.pem "${mods[@]}"
		local -x LD_LIBRARY_PATH="${ED}/usr/$(get_libdir):${LD_LIBRARY_PATH}"
		local mod
		for mod in "${mods[@]}"; do
			edob -m "Verifying signature for ${mod##*/}" ./ipa_verify "${mod}"
		done
		popd || die
		rm -r "${T}"/signing-scripts || die
	fi
}
