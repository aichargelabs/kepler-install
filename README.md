# KeplerCrew

Autonomous engineering cockpit by aichargelabs. This repository hosts the
KeplerCrew client installers. A valid license key is required — downloads are
license-gated; the installer scripts themselves are public.

## Install

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://get.keplercrew.com/install.ps1 | iex"
```

The installer prompts for your license key (input hidden). To run unattended:

```powershell
$env:KEPLER_LICENSE_KEY = "<your license key>"
powershell -ExecutionPolicy Bypass -Command "irm https://get.keplercrew.com/install.ps1 | iex"
```

### macOS / Linux

```sh
curl -fsSL https://get.keplercrew.com/install.sh | sh
```

## Updating

Re-run the same install command to update in place:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://get.keplercrew.com/install.ps1 | iex"
```

On macOS/Linux, re-run the installer to update in place:

```sh
curl -fsSL https://get.keplercrew.com/install.sh | sh
```

The installer reuses the stored license key from the previous install. To force a
reinstall even when already on the latest version, set `KEPLER_FORCE=1`.

## Options (environment variables)

| Variable | Effect |
| --- | --- |
| `KEPLER_LICENSE_KEY` | License key (skips the prompt; stored key is reused on update) |
| `KEPLER_VERSION` | Pin a version, e.g. `1.0.0` (default: latest) |
| `KEPLER_DRY_RUN=1` | Resolve and print the release without downloading |
| `KEPLER_INSTALL_DIR` | Install directory (default: `%LOCALAPPDATA%\Programs\KeplerCrew` on Windows, `~/.local/share/keplercrew` on Unix) |
| `KEPLER_NO_LAUNCH=1` | Install without launching |
| `KEPLER_FORCE=1` | Reinstall even when already on the resolved version |

## What the installer does

- Validates your license key before downloading anything.
- Downloads the latest bundle your license is entitled to, over HTTPS.
- Verifies the SHA256 checksum against the release metadata.
- Extracts to a per-user directory — no administrator access required.
- Stores your license key locally with user-only file permissions.
- Does not install telemetry.

## Getting a license

KeplerCrew is licensed software. For a trial or purchase, contact
support@aichargelabs.com or visit [keplercrew.com](https://keplercrew.com).

## Uninstall

Delete the install directory (default `%LOCALAPPDATA%\Programs\KeplerCrew`) and
`%USERPROFILE%\.kepler-trial`.

KeplerCrew is developed by aichargelabs.
