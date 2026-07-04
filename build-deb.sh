#!/bin/sh
# Reproducible build of libfprint-goodix-53xd_*.deb for Goodix 27c6:538d
# (Dell Latitude 3410 / Inspiron 7506 / Vostro 3500 ...).
# Run on Debian 13+ / Ubuntu 24.04+ with:
#   sudo apt install -y git meson ninja-build cmake pkg-config libglib2.0-dev \
#     libgusb-dev libgudev-1.0-dev libssl-dev libnss3-dev libpixman-1-dev binutils
set -eu

VERSION=1.94.1+53xd-2
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git clone --depth 1 -b unstable https://github.com/infinytum/libfprint.git "$WORK/src"
cd "$WORK/src"
sed -i "/common_cflags = cc.get_supported_arguments(\[/a \    '-Wno-incompatible-pointer-types'," meson.build
# tuning: richer enroll template and fewer false rejects on the tiny 80x64 sensor
sed -i 's/#define IMG_ENROLL_STAGES 5/#define IMG_ENROLL_STAGES 10/' libfprint/fp-image-device-private.h
sed -i 's/img_dev_class->bz3_threshold = 24;/img_dev_class->bz3_threshold = 18;/' libfprint/drivers/goodixtls/goodix53xd.c
meson setup build -Ddoc=false -Dintrospection=false -Dgtk-examples=false \
  -Dudev_rules=disabled -Dudev_hwdb=disabled
ninja -C build

PKG="$WORK/libfprint-goodix-53xd_${VERSION}_amd64"
LIB="$PKG/usr/lib/x86_64-linux-gnu/libfprint-goodix-53xd"
DOC="$PKG/usr/share/doc/libfprint-goodix-53xd"
mkdir -p "$LIB" "$PKG/etc/ld.so.conf.d" "$DOC" "$PKG/DEBIAN"

cp build/libfprint/libfprint-2.so.2.0.0 "$LIB/"
strip --strip-unneeded "$LIB/libfprint-2.so.2.0.0"
ln -s libfprint-2.so.2.0.0 "$LIB/libfprint-2.so.2"
echo "/usr/lib/x86_64-linux-gnu/libfprint-goodix-53xd" \
  > "$PKG/etc/ld.so.conf.d/00-libfprint-goodix-53xd.conf"

cat > "$PKG/DEBIAN/control" <<EOF
Package: libfprint-goodix-53xd
Version: $VERSION
Architecture: amd64
Maintainer: Jahed <muradpur.switch@gmail.com>
Section: libs
Priority: optional
Depends: libc6 (>= 2.38), libglib2.0-0t64 (>= 2.66), libgusb2 (>= 0.3.0), libssl3t64, libnss3, libpixman-1-0, libgudev-1.0-0
Enhances: fprintd
Homepage: https://github.com/infinytum/libfprint
Description: libfprint with Goodix TLS 53xd fingerprint driver (27c6:538d)
 Community-built libfprint 1.94.1 including the experimental goodixtls53xd
 driver for Goodix fingerprint sensors with USB ID 27c6:538d, found in the
 power button of Dell Latitude 3410, Inspiron 7506, Vostro 3500 and others.
 .
 The library installs into a private directory and shadows the distribution
 libfprint via an ld.so.conf.d entry; removing this package restores the
 stock library. The sensor may first need initialization with goodix-fp-dump.
 .
 This driver is experimental and community-maintained. Use as a convenience,
 not as strong security.
EOF

echo "/etc/ld.so.conf.d/00-libfprint-goodix-53xd.conf" > "$PKG/DEBIAN/conffiles"
printf '#!/bin/sh\nset -e\nldconfig\npkill -x fprintd 2>/dev/null || true\nexit 0\n' \
  > "$PKG/DEBIAN/postinst"
cp "$PKG/DEBIAN/postinst" "$PKG/DEBIAN/postrm"

cat > "$DOC/copyright" <<EOF
libfprint is Copyright (C) the libfprint authors, LGPL-2.1+.
See /usr/share/common-licenses/LGPL-2.1 on Debian systems.
Source: https://github.com/infinytum/libfprint (branch: unstable)
Goodix TLS drivers: https://github.com/goodix-fp-linux-dev
EOF
printf 'libfprint-goodix-53xd (%s) unstable; urgency=low\n\n  * Community build of the goodixtls53xd driver.\n  * 10 enroll stages; bz3 threshold 18.\n\n -- Jahed <muradpur.switch@gmail.com>  %s\n' \
  "$VERSION" "$(date -R)" > "$DOC/changelog.Debian"
gzip -9n "$DOC/changelog.Debian"

find "$PKG" -type d -exec chmod 755 {} +
find "$PKG/usr" "$PKG/etc" -type f -exec chmod 644 {} +
chmod 755 "$PKG/DEBIAN/postinst" "$PKG/DEBIAN/postrm" "$LIB/libfprint-2.so.2.0.0"

OUT=${1:-.}
dpkg-deb --build --root-owner-group "$PKG" "$OUT"
echo "Built: $OUT/libfprint-goodix-53xd_${VERSION}_amd64.deb"
