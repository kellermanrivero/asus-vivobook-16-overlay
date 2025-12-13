# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="A complex camera support library for Linux, Android, and ChromeOS"
HOMEPAGE="https://libcamera.org/"
SRC_URI="https://github.com/kellermanrivero/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="LGPL-2.1+"
SLOT="0"
KEYWORDS="~arm64"

DEPEND="
	dev-libs/libyaml:=
	dev-python/jinja2
	dev-python/ply
	dev-python/pyyaml
	|| (
		net-libs/gnutls
		dev-libs/openssl
	)
		debug? ( dev-libs/elfutils:= )
	gstreamer? ( media-libs/gstreamer:= )
	libevent?
	(
		dev-libs/libevent:=
		drm? ( x11-libs/libdrm:= )
		jpeg? ( media-libs/libjpeg-turbo:= )
		sdl? ( media-libs/libsdl2:= )
	)
	qt6?
	(
		dev-qt/qtbase:6
		dev-qt/qtbase:6[gui] 
		dev-qt/qtbase:6[widgets]
	)
	tiff? ( media-libs/tiff:= )
	trace? ( dev-util/lttng-ust:= )
	udev? ( virtual/libudev:= )
	unwind? ( sys-libs/libunwind:= )	
"
RDEPEND="${DEPEND}"
BDEPEND=""

#IUSE="debug drm gnutls gstreamer jpeg libevent qt5 sdl tiff trace udev unwind v4l2"
IUSE="debug drm gnutls gstreamer jpeg tiff libevent qt6 sdl trace udev unwind v4l"
REQUIRED_USE="qt6? ( tiff )"

src_configure() {
	local emesonargs=(
		# Broken for >=dev-pyhon/sphinx-7
		# $(meson_feature doc documentation)
		-Ddocumentation=disabled
		$(meson_feature libevent cam)
		$(meson_feature gstreamer)
		$(meson_feature qt6 qcam)
		$(meson_feature trace tracing)
		$(meson_use v4l v4l2)
	)

	meson_src_configure "-Dpipelines=simple"
}
