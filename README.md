# Rootless Podman with Quadlets for Homelab Setups 📦

This guide explains how to manage **rootless Podman containers** using **systemd Quadlets**, suitable for Raspberry Pi or other homelab environments.

> **Tested on:** Raspberry Pi 5 with Debian Trixi (Version 13) </br>
> **Podman version:** 5.4.2+  </br>
> **Firewall:** UFW recommended for port control </br>
> **SELinux:** Optional (not required)

## Features

- Rootless container setup only 
- Systemd-managed containers via Quadlets
- Templates for `.pod`, `.container`, `.network`, `.env`, `...` files
- Persistent storage support
- Automatic container updates via timer
- `Only ports 80, 443, 81 exposed by default with UFW` (Port 22 optional for SSH)
- Safe low port binding with `net.ipv4.ip_unprivileged_port_start=80` when using UFW
- `Nginx Proxy Manager handles all external access`; containers do not expose extra ports

---

### 1. Check if Podman is installed on the system; if not, install it.

```
command -v podman >/dev/null || sudo apt update && sudo apt install -y podman
```

---

### 2. Modifying unprivileged ports to access low-level ports

By default, rootless Podman cannot bind ports below 1024 on the host. If you try to map 80, 81 and 443 directly, it will fail!

Check the current config:

```
sysctl net.ipv4.ip_unprivileged_port_start
```

Output should be:

```
net.ipv4.ip_unprivileged_port_start = 1024
```

Allow unprivileged ports from 80:

- This default value can however be changed by making changes to file /etc/sysctl.d/99-rootless-podman-unprivileged-ports.conf
- Allow unprivileged (non-root) processes to bind to ports starting from 80.
- This is required for rootless Podman containers to listen on ports 80, 81 and 443 without using iptables redirects or running containers as root.
- This enables services like Nginx Proxy Manager to bind directly to ports 80-81/443 in rootless container setups.
- Ports below 80 (e.g. SSH on port 22) remain protected and require root privileges.

```
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-rootless-podman-unprivileged-ports.conf
```

Apply & verify:

```
sudo sysctl --system
sysctl net.ipv4.ip_unprivileged_port_start
```

Output should be:

```
net.ipv4.ip_unprivileged_port_start = 80
```

---

### 3. Set up the directories

```
mkdir -p ~/.config/containers/systemd/
```

Place your `.pod`, `.container`, `.network`, `.env`, `...` files in this directory.

---

### 4. Configure Persistent Storage on a SSD (Optional)

Rootless Podman uses $HOME/.local/share/containers by default. 

If you want your Podman containers’ data to persist outside the default rootless storage, you can use an external SSD or a separate storage path.

```
mkdir -p ~/.config/containers

id -u # Show your User-ID

nano ~/.config/containers/storage.conf

[storage]
driver = "overlay" # OverlayFS driver: efficient copy-on-write filesystem
runroot = "/run/user/1000/containers" # User-ID is 1000 here
graphroot = "/mnt/podman-data" # Mounted external SSD or custom path
```

> Other storage drivers exist (e.g., vfs, btrfs, zfs). See the official Podman documentation for details: https://docs.podman.io/en/v5.4.2/markdown/podman.1.html

For rootless Podman, make sure your user owns the directory on the SSD:

```
chown -R $(whoami):$(whoami) /mnt/podman-data
chmod -R 755 /mnt/podman-data
```

### 5 Create a seperate podman network for example the Nginx Proxy Manager

```
podman network create proxy.net
```

Note / Special Considerations:

- This network will be used by `Nginx Proxy Manager` to `handle external access`.
- Later, additional networks can be created for other containers or services (e.g., Vaultwarden, Jellyfin).
- `Nginx Proxy Manager` can `join all networks to reverse proxy requests`, while containers themselves remain isolated by default.
- By default, containers do not communicate with each other unless they are explicitly grouped in a pod. This ensures better security and `network separation` in your homelab setup.

### 6. Create a .container file for example the Nginx Proxy Manager

```
nano ~/.config/containers/systemd/nginx-proxy-manager.container
```

```
[Unit]
Description=Nginx Proxy Manager (Rootless Podman)
# Requires Podman version >= 5.4.2

# Network must be online before the container starts
After=network-online.target
Wants=network-online.target

[Container]
ContainerName=nginx-proxy-manager
Image=docker.io/jc21/nginx-proxy-manager:latest

# Automatical Updates
# To enable automatic updates for all containers, start the systemd timer:
# systemctl --user start --now radicale.auto-update.timer
AutoUpdate=registry

# Network
# Isolated container network
# IMPORTANT: The network must exist before starting this service!
# podman network create proxy.net
Network=proxy.net
# Connect the nginx-proxy-manager to another networks. For example: vaultwarden.net
# Network=vaultwarden.net
PublishPort=80:80
PublishPort=443:443
PublishPort=81:81

# Timezone
# This option tells Podman to set the time zone based on the local system's time zone where Podman is running.
Timezone=local

# IMPORTANT: The container starts internally as root, as expected by the NPM container.
# NPM then automatically changes the data ownership to PUID/PGID (here 1000:1000).
# This corresponds exactly to the recommendation in the error message:
# "This Docker container must be run as root, do not specify a user. You can specify PUID and PGID env vars..."
Environment=PUID=1000
Environment=PGID=1000

# Volumes
Volume=nginx-proxy-manager_data:/data:Z
Volume=nginx-proxy-manager_letsencrypt:/etc/letsencrypt:Z

# Healthcheck on dashboard port
HealthCmd=["CMD", "/usr/bin/check-health"]
HealthInterval=10s
HealthTimeout=3s
HealthRetries=3
HealthStartPeriod=10s
HealthOnFailure=kill

[Service]
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

### 7. Start and Enable Auto-Update Timer

Once you have created your `podman-auto-update.service` and `podman-auto-update.timer` in the `~/quadlets/containers/` folder, start and enable the timer:

```
systemctl --user start --now podman-auto-update.timer
```

Explanation:

- `--user` → runs the service for your user (rootless Podman)
- `--now` → starts the timer immediately and enables it to run at boot
- The timer will now execute the `podman-auto-update.service` according to the schedule defined (e.g., every 24 hours).

Check the timer status:

```
systemctl --user status podman-auto-update.timer
```

### 8. Enable User Linger (Headless Setup)

Activates linger for your user account. User systemd services (like your Rootless Podman container service) will start automatically at boot, even if no one logs in. This is perfect for headless Raspberry Pi setups.

```
loginctl enable-linger $USER
```

Verify that linger is enabled:

```
loginctl show-user $USER | grep Linger
```

Why it matters:

- Without linger, systemd user services like your rootless container services and auto-update timer will not start automatically at boot.
- Enabling linger ensures that rootless Podman timers (podman-auto-update.timer) and container services run on headless setups like a Raspberry Pi homelab.

### 9. Reload Systemd for User Services

After creating or modifying any Quadlet files (`.container`, `.network`, `.env`, `...`), you must reload the systemd user daemon so your changes are recognized:

```
systemctl --user daemon-reload
```

Check that systemd has recognized your services:

```
systemctl --user list-units --type=service
systemctl --user list-timers
```

> ⚡ Tip: Always reload systemd after adding or editing Quadlets before starting or enabling services.

### 10. Start the container

Once your `.container` Quadlet is ready and systemd has been reloaded, start the container:

```
systemctl --user start nginx-proxy-manager.service
```

### 11. Check if the Podman Container is Running

Verify that your rootless container is up and running:

```
podman ps
```

### 12. Healthcheck for example the Nginx Proxy Manager

You can test whether Nginx Proxy Manager is working correctly:

```
podman inspect -f '{{.State.Health.Status}}' nginx-proxy-manager
```
