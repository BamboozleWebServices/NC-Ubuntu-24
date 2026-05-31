# nextcloud-ubuntu2404

An interactive Nextcloud installer for **Ubuntu 24.04 LTS**.

Fork of Carsten Rieger's [`criegerde/nextcloud-zero`](https://codeberg.org/criegerde/nextcloud-zero).
The installation engine is his work — all credit to [c-rieger.de](https://www.c-rieger.de).
This fork replaces the `zero.cfg` file with **interactive prompts** and bakes in
opinionated defaults.

## Requirements

- Ubuntu 24.04 LTS (x86_64), fresh server
- root / sudo access
- A **public domain** resolving to the server with ports 80 + 443 open
  (Let's Encrypt is enabled by default)

## Install

Download and run it — do not pipe through `curl | bash`, the wizard reads keyboard input.

```bash
sudo -s
apt install -y wget curl dnsutils
wget -O nextcloud-ubuntu2404.sh https://raw.githubusercontent.com/BamboozleWebServices/NC-Ubuntu-24/main/nextcloud-ubuntu2404.sh
chmod +x nextcloud-ubuntu2404.sh
./nextcloud-ubuntu2404.sh
```

## What the wizard asks

| Prompt | Type | Notes |
|---|---|---|
| Public domain | text (required) | must resolve to this server |
| Admin username | text | default `ncadmin` |
| Admin password | choice | auto-generate or type your own |
| Region | menu | UAE / DE / AT / UK / custom (timezone + phone region) |
| Max upload size | text | default `10G` |

## Baked-in defaults (no longer prompted)

- **PHP 8.4**
- **MariaDB**
- **Let's Encrypt** (auto-renewing)
- No office suite installed (community OnlyOffice is unsupported on Nextcloud 33)
- Data path `/nc_data`, Nextcloud `latest`, DB name/user `nextcloud`
- DB / MariaDB-root / Redis passwords — auto-generated

To change any of these, edit the **"Fixed defaults"** block near the top of the script.
(For a LAN-only box with no public domain, set `LETSENCRYPT="n"` there.)

## Updating

This fork hosts its **own copy** of the update script (`update.sh`) so you don't
depend on upstream availability and can customise it.

**One-time setup when you create the repo:**

```bash
# 1. grab the current upstream update script into your repo
wget -O update.sh https://codeberg.org/criegerde/nextcloud/raw/branch/master/skripte/update.sh

# 2. edit UPDATESCRIPTURL (line 14 of nextcloud-ubuntu2404.sh) to your repo's raw path
# 3. commit both files
git add nextcloud-ubuntu2404.sh update.sh README.md && git commit -m "Add self-hosted update script"
```

The installer then downloads `update.sh` from **your** repo into `~/update.sh`.
To update Nextcloud core afterwards:

```bash
sudo ~/update.sh
```

Re-pull the upstream `update.sh` into your repo every so often to stay current.

> Automated/unattended Nextcloud upgrades are **not** enabled by default — major
> version jumps can break apps. Run updates manually.

## Credit

Original installer and update script © Carsten Rieger IT-Services — https://www.c-rieger.de
