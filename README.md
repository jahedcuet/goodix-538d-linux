# Goodix 27c6:538d fingerprint sensor on Linux

Make the Goodix fingerprint sensor (USB ID `27c6:538d`, built into the power
button of the **Dell Latitude 3410, Inspiron 7506, Vostro 3500** and similar
Dell laptops) work with `fprintd` on Linux.

There is no official Linux driver for this sensor and the Dell/Ubuntu TOD
driver covers a different chip (53xc). This repo packages the community
`goodixtls53xd` driver from
[infinytum/libfprint](https://github.com/infinytum/libfprint) (branch
`unstable`, based on libfprint 1.94.1, written by the
[goodix-fp-linux-dev](https://github.com/goodix-fp-linux-dev) community) as a
clean Debian package, with two tuning patches that took verification from
~1-in-3 matches to 3-for-3 in testing:

- 10 enrollment stages instead of 5 (richer template)
- bozorth3 match threshold 24 → 18 (fewer false rejects)

Verified end-to-end on a Latitude 3410 running Debian 13 "trixie"
(fprintd 1.94.5), July 2026.

> **Disclaimer:** experimental community driver. The sensor's TLS pairing
> security is effectively disabled (zeroed PSK), and matching is more
> permissive than the Windows driver. Treat fingerprint unlock as a
> convenience, not strong security. Firmware flashing (step 1) carries a
> small risk of bricking the sensor and will make Windows Hello re-pair on
> the next Windows boot. Use at your own risk.

## Install

### Step 0 — confirm the sensor

```console
$ lsusb -d 27c6:
Bus 001 Device 003: ID 27c6:538d Shenzhen Goodix Technology Co.,Ltd. FingerPrint
```

The product ID must be `538d`. Other Goodix IDs need different drivers.

### Step 1 — one-time sensor initialization

The sensor may need its firmware checked/flashed and pairing key reset once,
using [goodix-fp-dump](https://github.com/goodix-fp-linux-dev/goodix-fp-dump):

```sh
sudo apt install -y fprintd libpam-fprintd git python3-venv
git clone --recurse-submodules https://github.com/goodix-fp-linux-dev/goodix-fp-dump.git
cd goodix-fp-dump
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
sudo .venv/bin/python3 run_538d.py
```

Success looks like `Firmware: GF5298_GM168SEC_APP_13016`, `Valid PSK: True`,
then "Waiting for finger…" — touch the sensor and it saves a test image.
Some units (like the tested Latitude 3410) already ship in the right state
and nothing is flashed. **Do not interrupt it while it writes firmware.**
If it aborts with "Invalid firmware", stop and ask upstream — don't force it.

### Step 2 — install the driver package

Download the `.deb` from the
[latest release](../../releases/latest) and:

```sh
sudo apt install ./libfprint-goodix-53xd_*_amd64.deb
```

The package installs the library into its own directory
(`/usr/lib/x86_64-linux-gnu/libfprint-goodix-53xd/`) plus an
`ld.so.conf.d` entry that makes the dynamic loader prefer it over the
distro's libfprint. **No distro files are replaced.**

Prefer to build it yourself? `./build-deb.sh` reproduces the package from
source (build deps listed in the script header).

### Step 3 — enroll and enable

```sh
fprintd-enroll                          # ~11 touches; vary the angle slightly
fprintd-verify                          # expect: verify-match
sudo pam-auth-update --enable fprintd   # fingerprint for sudo / login / lock screen
```

## Uninstall

```sh
sudo apt remove libfprint-goodix-53xd   # restores stock libfprint
sudo pam-auth-update                    # disable the fprintd PAM module
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| fprintd: "No devices available" | `sudo pkill fprintd`, retry. Check `ldd /usr/libexec/fprintd \| grep libfprint` points at the `libfprint-goodix-53xd` directory. |
| `enroll-duplicate` but `fprintd-list $USER` shows nothing | A stray print under **another user** (often root) matches your finger — fprintd checks duplicates across all users. `sudo ls -R /var/lib/fprint`, remove stale dirs (e.g. `sudo rm -rf /var/lib/fprint/root`), `sudo pkill fprintd`. |
| Frequent "no match" on verify | Re-enroll with flat, full-coverage touches. Enrolling the same finger under two finger names also helps. |
| Breaks after a distro upgrade | A newer fprintd may need symbols this 1.94.1-based fork lacks. `sudo apt remove libfprint-goodix-53xd` until the package is rebuilt. |
| Sensor stops responding | Re-run step 1; a reboot re-enumerates the USB device. |

A longer illustrated walkthrough of how this was debugged and verified is in
[GUIDE.md](GUIDE.md).

## Credits

- Driver and protocol reverse engineering:
  [goodix-fp-linux-dev](https://github.com/goodix-fp-linux-dev) community
- libfprint: [freedesktop.org](https://gitlab.freedesktop.org/libfprint/libfprint)
- Related: [Ubuntu bug #1879247](https://bugs.launchpad.net/bugs/1879247),
  [AUR libfprint-goodix-521d](https://aur.archlinux.org/packages/libfprint-goodix-521d)

## License

libfprint and the packaged library are LGPL-2.1-or-later. Packaging and
scripts in this repo: LGPL-2.1-or-later.
