# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
PYTHON_COMPAT=( python3_{13..14} )

inherit meson
inherit python-any-r1

DESCRIPTION="A complex camera support library for Linux, Android, and ChromeOS"
HOMEPAGE="https://libcamera.org"
SRC_URI="https://gitlab.freedesktop.org/camera/libcamera/-/archive/v${PV}/libcamera-v${PV}.tar.bz2 -> ${P}.tar.bz2"
S="${WORKDIR}/libcamera-v${PV}"
LICENSE="Apache-2.0 CC0-1.0 BSD-2 CC-BY-4.0 CC-BY-SA-4.0 GPL-2+ GPL-2 LGPL-2.1+"
SLOT="0"
KEYWORDS="~arm64"
IUSE="drm gnutls openssl gstreamer jpeg tiff libevent qt6 sdl trace +udev unwind v4l test"
REQUIRED_USE="qt6? ( tiff )"

DEPEND="
	dev-libs/libyaml:=
	openssl? ( dev-libs/openssl:= )
	gnutls? ( net-libs/gnutls:= )
	gstreamer? (
		>=media-libs/gstreamer-1.14.0:1.0
		>=media-libs/gst-plugins-base-1.14:1.0
	)
	libevent? (
		dev-libs/libevent:=
		drm? ( x11-libs/libdrm:= )
		sdl? (
			media-libs/libsdl2:=
			jpeg? ( media-libs/libjpeg-turbo:= )
		)
	)
	qt6? (
		dev-qt/qtbase:6
		dev-qt/qtbase:6[gui,widgets]
	)
	tiff? ( media-libs/tiff:= )
	trace? (
		dev-util/lttng-ust:=
		dev-cpp/gtest:=
	)
	udev? ( virtual/libudev:= )
	unwind? ( sys-libs/libunwind:= )
	test? ( media-libs/libyuv:= )
"
RDEPEND="${DEPEND}"
BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep '
		dev-python/jinja2[${PYTHON_USEDEP}]
		dev-python/ply[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
	')
"

RESTRICT="!test? ( test )"
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
		# Broken for >=dev-pyhon/sphinx-7
		# $(meson_feature doc documentation)
		-Ddocumentation=disabled
		$(meson_feature libevent cam)
		$(meson_feature drm cam-drm-sink)
		$(meson_feature sdl cam-sdl-sink)
		$(meson_feature jpeg cam-sdl-jpeg)
		$(meson_feature tiff tiff)
		$(meson_feature gstreamer)
		$(meson_feature gnutls)
		$(meson_feature openssl)
		$(meson_feature qt6 qcam)
		$(meson_feature trace tracing)
		$(meson_feature unwind libunwind)
		$(meson_feature udev)
		$(meson_use test)
		$(meson_use v4l v4l2)
	)

	# TODO: Skipping 'rpi/pisp' and 'virtual' pipelines.
	# 	- Pipeline 'rpi/pisp' depends on libpisp not available in Gentoo repository yet.
	# 	- Pipeline 'virtual' depends on libyuv but seems to be only used during tests.
	meson_src_configure "-Dpipelines=imx8-isi,ipu3,mali-c55,rkisp1,rpi/vc4,simple,uvcvideo,vimc"
}
