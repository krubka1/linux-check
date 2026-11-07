# Linux-Check

A small Windows program that checks whether your PC is a good fit for Linux
**before** you install it. It looks at your hardware and gives a verdict:
**GO**, **CAUTION** or **NO-GO**, with the reason for every warning.

*O'zbekcha qo'llanma [pastda](#ozbekcha).*

Example output (shortened):

```
=== Linux Compatibility Check ===

[INFO] Machine        Example Laptop 15
[INFO] CPU            AMD Ryzen 5 5600H with Radeon Graphics
[OK  ] Architecture   64-bit x86
[OK  ] RAM            15.4 GB
[OK  ] Free disk      112 GB on C:
[OK  ] Firmware       UEFI
[WARN] Secure Boot    On. Most big distros (Ubuntu, Fedora, Mint) boot fine; others need it off.
[WARN] GPU            NVIDIA GeForce GTX 1650: works, but best with the proprietary driver.
...
--- Verdict ---
CAUTION: 2 known risk(s) above. Likely works, but some feature may need manual setup.
```

## What it checks

| Check | Why it matters |
|---|---|
| CPU architecture | 32-bit-only and ARM (Snapdragon) PCs have limited distro support |
| RAM, free disk space | Enough for a desktop and for dual boot |
| UEFI / Secure Boot | Some distros need Secure Boot turned off |
| Storage mode (Intel RST / VMD / RAID) | The installer may not see your SSD until you switch to AHCI |
| GPU | NVIDIA needs its proprietary driver; Intel/AMD work out of the box |
| Wi-Fi chip | Some Broadcom/Realtek chips need extra drivers |
| Fingerprint reader, IR camera | Often unsupported on Linux |
| Known-device list | PCI/USB IDs matched against [`devices.json`](devices.json) |

It also saves `linux-check-report.txt` next to the program, with your hardware
IDs, so you can look them up on [linux-hardware.org](https://linux-hardware.org).

## Safety

- **Read-only.** It only *reads* system information (WMI/CIM queries, one
  registry key for Secure Boot). It changes no settings, installs nothing,
  needs no administrator rights, and uses no network.
- **Nothing is sent anywhere.** The only file it writes is the report text file.
- **All the logic is one readable script:** [`Linux-Check.ps1`](Linux-Check.ps1)
  (~150 lines). The `.exe` is just a launcher ([`main.go`](main.go)) that unpacks
  that script and `devices.json` into a temp folder, runs them with Windows'
  own PowerShell, and deletes the temp folder.
- **The release `.exe` files are built by GitHub Actions** from this source
  ([workflow](.github/workflows/release.yml)), not on someone's PC. Each one has
  a signed build-provenance attestation and a checksum in `SHA256SUMS.txt`.

### Verify the .exe yourself

Check the hash (PowerShell):

```powershell
Get-FileHash .\Linux-Check-amd64.exe -Algorithm SHA256
```

It must match the line in `SHA256SUMS.txt` from the same release.

Check that GitHub built it from this repo (needs the [GitHub CLI](https://cli.github.com)):

```sh
gh attestation verify Linux-Check-amd64.exe --repo OWNER/linux-check
```

Or rebuild it yourself and compare hashes. The build is deterministic: with
the official Go release pinned in `go.mod` it should give the same bytes as
the release (Linux distro builds of Go may carry patches that change the output).

```sh
sh build.sh        # needs Go; prints SHA-256 of dist/*.exe
```

### Don't want to run an .exe at all?

Download `Linux-Check.ps1`, `devices.json` and `Linux-Check.bat` into one
folder and double-click `Linux-Check.bat`. It does exactly the same thing.

## Usage

1. Download `Linux-Check-amd64.exe` from [Releases](../../releases)
   (`arm64` only for Snapdragon/ARM laptops).
2. Double-click it. Windows SmartScreen may say "Windows protected your PC"
   because the file is not code-signed: click **More info → Run anyway**.
3. Read the report. Press Enter to close.

## Limits

This is **not a guarantee**. It only knows about common problem areas, and the
device list is small and hand-curated: "nothing flagged" means nothing *known*.
The real test is a live USB: boot Ubuntu, Fedora or Mint from a USB stick and
check Wi-Fi, sound, suspend and screen brightness. Back up your data and your
BitLocker recovery key before installing anything.

## Contributing

Know a device that does or doesn't work? Add it to `devices.json`:

```json
{"id":"vendor:device", "status":"OK|WARN|BAD|INFO", "name":"...", "note":"..."}
```

`id` is the PCI/USB vendor and device ID in lowercase hex (`10ec:c821`), or
`vendor:*` for a whole vendor. An exact ID wins over a `vendor:*` rule.

## License

[MIT](LICENSE)

---

## O'zbekcha

**Linux-Check** — kompyuteringiz Linux uchun mosmi yoki yo'qligini o'rnatishdan
**oldin** tekshiradigan kichik Windows dasturi. Natija: **GO** (bemalol),
**CAUTION** (ehtiyot bo'ling) yoki **NO-GO** (hozircha o'rnatmang).

**Xavfsizmi?**

- Dastur faqat ma'lumot **o'qiydi**: hech narsani o'zgartirmaydi, hech narsa
  o'rnatmaydi, administrator huquqi va internet kerak emas.
- Hech qayerga hech narsa yuborilmaydi. Faqat `linux-check-report.txt` faylini
  yozadi (qurilmalaringiz ID raqamlari).
- Butun mantiq bitta ochiq skriptda: [`Linux-Check.ps1`](Linux-Check.ps1).
  `.exe` faqat shu skriptni ishga tushiradi.
- Releases'dagi `.exe` fayllarni GitHub o'zi shu koddan yig'adi, ularning
  SHA-256 xeshi `SHA256SUMS.txt` faylida.

**Qanday ishlatiladi:**

1. [Releases](../../releases) bo'limidan `Linux-Check-amd64.exe` ni yuklab oling.
2. Ikki marta bosing. "Windows protected your PC" chiqsa:
   **More info → Run anyway**.
3. Natijani o'qing, yopish uchun Enter bosing.

`.exe` ishga tushirishni xohlamasangiz: `Linux-Check.ps1`, `devices.json` va
`Linux-Check.bat` ni bitta papkaga yuklab, `Linux-Check.bat` ni bosing.

Bu **kafolat emas**. Eng ishonchli yo'l: Live USB'dan Ubuntu, Fedora yoki
Mint'ni ishga tushirib, Wi-Fi, ovoz va boshqalarni tekshirib ko'ring.
O'rnatishdan oldin ma'lumotlaringizning zaxira nusxasini oling.

Savollar: [t.me/lowlevelUZ](https://t.me/lowlevelUZ)
