# Trojan-Go SNI One-Click Installer

Production-oriented Trojan-Go deployment project for Ubuntu and Debian servers. It installs Trojan-Go, Nginx Stream SNI routing, Let's Encrypt certificates, a local static camouflage site, systemd services, logs, backups, rollback, renewal and Trojan-Go updates.

## Supported Systems

- Ubuntu 22.04 or newer
- Debian 12 or newer
- amd64 and arm64
- Bash 5.x
- root execution

## Project Layout

```text
.
├── config.env
├── install.sh
├── uninstall.sh
├── update.sh
├── renew.sh
├── setup-menu.sh
├── trojan
├── lib/
│   ├── backup.sh
│   ├── certbot.sh
│   ├── client.sh
│   ├── common.sh
│   ├── nginx.sh
│   ├── system.sh
│   ├── templates.sh
│   └── trojan.sh
├── templates/
│   ├── logrotate.conf.tpl
│   ├── nginx-http.conf.tpl
│   ├── nginx-stream.conf.tpl
│   ├── site-index.html.tpl
│   ├── trojan-go-config.json.tpl
│   ├── trojan-go-sni-renew.service.tpl
│   ├── trojan-go-sni-renew.timer.tpl
│   └── trojan-go.service.tpl
├── LICENSE
└── README.md
```

## What It Deploys

- Nginx with the stream module.
- Nginx `ssl_preread` SNI routing on external port `443`.
- Trojan SNI routed to `127.0.0.1:${TROJAN_PORT}`.
- Website SNI and default SNI routed to `127.0.0.1:8443`.
- Same-domain camouflage mode by default: the website domain can be the same as the Trojan SNI domain.
- Trojan-Go fallback routed to the local static site on `127.0.0.1:${TROJAN_REMOTE_PORT}`.
- External HTTP port `80` redirecting to HTTPS.
- Trojan-Go TLS TCP server with `ALPN=http/1.1`.
- Let's Encrypt certificates for both Trojan and website domains.
- A responsive static HTML5/CSS3 camouflage website with no CDN dependency.
- systemd service for Trojan-Go.
- systemd timer for certificate renewal.
- Log files under `/var/log/trojan-go-sni`.
- Backups under `/var/backups/trojan-go-sni`.
- Runtime configuration under `/etc/trojan-go-sni/config.env`.
- Client URI and QR code under `/etc/trojan-go-sni`.
- 中文管理菜单命令 `/usr/local/bin/trojan`。

## Install

```bash
git clone https://github.com/xboardnext999/trojan-nginx.git
cd trojan-nginx
sudo bash install.sh
```

The installer prompts for:

- Trojan domain
- Trojan backend port, default `8080`
- Trojan password, empty input generates a random password
- Camouflage website domain, defaulting to the Trojan domain
- IPv6 enablement, `Y` or `N`

The installer validates DNS before requesting certificates. For IPv4, each unique domain must have an `A` record pointing to the server public IPv4. When IPv6 is enabled, each unique domain must also have an `AAAA` record pointing to the server public IPv6.

## 中文管理菜单

安装完成后执行：

```bash
trojan
```

进入菜单后只需要输入数字，例如 `1`、`2`、`3`，不需要记其它命令。

菜单功能：

- 查看生成的配置信息
- 查看证书生效时间、到期时间、剩余天数
- 查看自动续订是否开启
- 查看 Trojan-Go、Nginx、自动续订服务状态
- 查看客户端链接和二维码
- 手动续期证书
- 升级 Trojan-Go
- 重启 Nginx 和 Trojan-Go
- 查看最近日志
- 重新生成二维码
- 卸载部署

如果你已经安装过旧版本，只想补上中文菜单，不想重新安装，执行：

```bash
git pull
sudo bash setup-menu.sh
trojan
```

## Same-Domain Camouflage

The recommended deployment is to use the same domain for Trojan and the camouflage website:

```text
Trojan domain: example.com
Camouflage website domain: example.com
```

With the same domain, Nginx cannot split one identical SNI value into two different backends. The generated configuration routes that SNI to Trojan-Go. Normal browser HTTPS requests are then handled by Trojan-Go fallback and served by the local static website on `127.0.0.1:8081`.

The generated camouflage site is:

- HTML5
- CSS3
- responsive
- minimalist
- normal website style
- no CDN
- all resources local or inline

## Renew Certificates

```bash
sudo bash /opt/trojan-go-sni/renew.sh
```

Automatic renewal is installed as:

```bash
systemctl status trojan-go-sni-renew.timer
```

## Update Trojan-Go

```bash
sudo bash /opt/trojan-go-sni/update.sh
```

The update command downloads the official latest Trojan-Go release for the detected architecture, replaces the binary, restarts Trojan-Go and rolls back the binary if the update fails.

## Uninstall

```bash
sudo bash /opt/trojan-go-sni/uninstall.sh
```

Remove runtime files, logs, web root and Trojan-Go binary:

```bash
sudo bash /opt/trojan-go-sni/uninstall.sh --purge --yes
```

## Runtime Commands

```bash
systemctl status trojan-go
systemctl status nginx
systemctl list-timers trojan-go-sni-renew.timer
journalctl -u trojan-go -n 100 --no-pager
tail -f /var/log/trojan-go-sni/trojan-go.log
```

## Generated Client Example

After installation, the script prints:

- Trojan domain
- Port `443`
- Password
- SNI
- Certificate path
- Client configuration example
- Terminal QR code

The same values are stored in:

```bash
/etc/trojan-go-sni/config.env
```

The generated client link and QR code files are:

```bash
/etc/trojan-go-sni/client.uri
/etc/trojan-go-sni/client-qr.png
/etc/trojan-go-sni/client-qr.txt
```

## Recovery

Each installer, renewal, update and uninstall operation creates a timestamped backup under:

```bash
/var/backups/trojan-go-sni
```

If a managed step fails, the script restores files from the current operation backup and attempts to restart affected services.
