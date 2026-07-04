# Building from source & how this was debugged

The README covers the packaged install. This page is for people who want to
build manually, or who hit something odd and want to know what to expect.

## Manual source build (instead of the .deb)

```sh
sudo apt install -y meson ninja-build cmake pkg-config libglib2.0-dev \
  libgusb-dev libgudev-1.0-dev libssl-dev libnss3-dev libpixman-1-dev

git clone --depth 1 -b unstable https://github.com/infinytum/libfprint.git
cd libfprint

# needed for modern GCC
sed -i "/common_cflags = cc.get_supported_arguments(\[/a \    '-Wno-incompatible-pointer-types'," meson.build
# tuning: richer enroll template + fewer false rejects (strongly recommended)
sed -i 's/#define IMG_ENROLL_STAGES 5/#define IMG_ENROLL_STAGES 10/' libfprint/fp-image-device-private.h
sed -i 's/img_dev_class->bz3_threshold = 24;/img_dev_class->bz3_threshold = 18;/' libfprint/drivers/goodixtls/goodix53xd.c

meson setup build --prefix=/usr/local -Ddoc=false -Dintrospection=false \
  -Dgtk-examples=false -Dudev_rules=disabled -Dudev_hwdb=disabled
ninja -C build
```

Test before installing — no root needed:

```console
$ build/examples/img-capture test.pgm
Selected device 0 (Goodix TLS Fingerprint Sensor 53XD) claimed by goodixtls53xd driver
# touch the sensor; test.pgm should contain a visible fingerprint
```

Install (shadows the distro libfprint via /usr/local; reversible):

```sh
sudo ninja -C build install && sudo ldconfig
ldd /usr/libexec/fprintd | grep libfprint   # must show /usr/local/...
```

Rollback: `sudo rm /usr/local/lib/x86_64-linux-gnu/libfprint-2.so* && sudo ldconfig`

## Notes from the field (Latitude 3410, Debian 13)

- **No flash was needed** on this unit: firmware was already
  `GF5298_GM168SEC_APP_13016` with a zeroed PSK, so `run_538d.py` only
  captured test images. Other units will get flashed — don't interrupt.
- **ABI compatibility**: Debian's fprintd 1.94.5 needs 47 `fp_*` symbols;
  all are exported by this 1.94.1-based fork with the matching
  `LIBFPRINT_2.0.0` version tag. Checked with
  `objdump -T /usr/libexec/fprintd | grep UND` vs `nm -D` on the fork.
- **The `enroll-duplicate` trap**: fprintd (≥1.94.5) runs an identify pass
  against *all users'* stored prints before enrolling. A leftover print
  under `/var/lib/fprint/root/` (from an old test) intermittently matched
  and blocked enrollment with `enroll-duplicate`, while
  `fprintd-list <user>` showed nothing. Debug with:

  ```sh
  sudo sh -c 'pkill fprintd; G_MESSAGES_DEBUG=all /usr/libexec/fprintd -t > /tmp/fprintd.log 2>&1 &'
  fprintd-enroll; grep discover /tmp/fprintd.log
  ```

- **Why the tuning patches**: with the stock 5 enroll stages and threshold
  24, verification matched ~1 attempt in 3. With 10 stages and threshold 18
  it matched 3-for-3. Threshold 18 is still mid-range among in-tree
  libfprint image drivers (they span 9–30).
- **Leftover Dell TOD packages** (`libfprint-2-tod1`,
  `libfprint-2-tod1-goodix`) target the 53xc chip and are dead weight for
  538d — safe to remove.
