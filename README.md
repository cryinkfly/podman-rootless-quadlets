# Rootless Podman service configurations using Quadlets for homelab setups. 📦

## Features
- Rootless container setup
- Systemd-managed containers with Quadlet
- Ready-to-use templates for .container, .network, and .env
- Tested on Raspberry Pi 5 with Debian Trixi
- As an example, the nginx proxy manager is set up here, and SELinux is not installed.
- Podman version 5.4.2 and heighter

### 1. Check if Podman is installed on the system; if not, install it.

     command -v podman >/dev/null || sudo apt update && sudo apt install -y podman

### 2. Set up the directories

     mkdir -p ~/.config/containers/systemd/

Place your .container, .network, and .env files in this directory.

### 3. Create a .container file for example the Nginx Proxy Manager

    nano ~/.config/containers/systemd/nginx-proxy-manager.container

```
[Unit]
Description=Nginx Proxy Manager (Rootless Podman)
After=network-online.target
Wants=network-online.target

[Container]
ContainerName=nginx-proxy-manager
Image=docker.io/jc21/nginx-proxy-manager:latest

# Network
Network=proxy.net
# Connect the nginx-proxy-manager to another networks. For example: vaultwarden.net
# Network=vaultwarden.net
PublishPort=80:80
PublishPort=443:443
PublishPort=81:81

# Volumes
Volume=nginx-proxy-manager_data:/data:Z
Volume=nginx-proxy-manager_letsencrypt:/etc/letsencrypt:Z

# Environment
Environment=TZ=Europe/Berlin

[Service]
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

#### 3.1 Create two files for the Auto-Update function: 

    nano ~/.config/containers/systemd/podman-auto-update.service

```
[Unit]
Description=Auto-update multiple Podman Containers

[Service]
Type=oneshot
ExecStart=/usr/bin/podman auto-update nginx-proxy-manager
#ExecStart=/usr/bin/podman auto-update container2
#ExecStart=/usr/bin/podman auto-update container3
# ...
```

    nano ~/.config/containers/systemd/podman-auto-update.timer

```
[Unit]
Description=Run Podman AutoUpdate every hour

[Timer]
OnBootSec=5min # Start 5 minutes after boot
OnUnitActiveSec=24h # Then repeat every 24 hours
Unit=podman-auto-update.service

[Install]
WantedBy=default.target

```

> Timer (podman-auto-update.timer)

- Runs the auto-update service at scheduled intervals (e.g., every 24 hours).
- Does not execute immediately when you start the timer; it waits for the next scheduled time.

> Service (podman-auto-update.service)

- Executes the actual commands to update the containers.
- Can be run manually to immediately check for updates and restart containers if needed.

### 4 Create a seperate podman network

    podman network create proxy

### 5. Reload systemd

    systemctl --user daemon-reload

### 6. Prepare persistent storage (Optional)

Before starting your container, you can create directories for persistent storage if you want data to survive container recreation or be stored on an external drive.

Default Rootless Podman path:

    $HOME/.local/share/containers/storage/volumes/


Or you repare the directories on a separate mounted SSD for example: /mnt/ssd

    mkdir -p ~/.config/containers

    id -u # Show your user-id

    nano ~/.config/containers/storage.conf

    [storage]
    driver = "overlay"
    runroot = "/run/user/1000/containers" #user-ID is 1000 here
    graphroot = "/mnt/podman-data" # For example to my external SSD

```
# For rootless Podman, make sure your user owns the directory on the SSD:
chown -R $(whoami):$(whoami) /mnt/podman-data
chmod -R 755 /mnt/podman-data
```

Important:

- This step is only necessary if you want persistent data outside the container.
- If you skip this step, Podman will use its default storage path, and all data will remain inside the container.

### 7. Start the container

    systemctl --user start nginx-proxy-manager.service

### 8. Check if the Podman container is running:

    podman ps

### 9. Enable Linger for Headless User (No Root Required)

Run this as your normal user:

    loginctl enable-linger

Explanation: Activates linger for your user account. User systemd services (like your Rootless Podman container service) will start automatically at boot, even if no one logs in. This is perfect for headless Raspberry Pi setups.

Check if linger is enabled:

    loginctl show-user $USER | grep Linger

To disable linger (also without root):

    loginctl disable-linger

### 10. Troubleshooting

If something goes wrong, check logs:

    journalctl --user -u nginx-proxy-manager.service --no-pager -n 50

<br/>

---

<br/>

### ⚠️ Rootless Podman & Low Ports (<1024)

By default, rootless Podman cannot bind ports below 1024 on the host. If you try to map 80 or 443 directly, it will fail!

Check the current config:

    sysctl net.ipv4.ip_unprivileged_port_start

Output should be:

    net.ipv4.ip_unprivileged_port_start = 1024

Allow unprivileged ports from 80:

> This default value can however be changed by making changes to file /etc/sysctl.d/99-rootless-podman-unprivileged-ports.conf

    # Allow unprivileged (non-root) processes to bind to ports starting from 80.
    # This is required for rootless Podman containers to listen on ports 80 and 443
    # without using iptables redirects or running containers as root.
    # This enables services like Nginx Proxy Manager to bind directly to ports 80/443
    # in rootless container setups.
    # Ports below 80 (e.g. SSH on port 22) remain protected and require root privileges.
    
    echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-rootless-podman-unprivileged-ports.conf

Apply & verify:

    sudo sysctl --system
    sysctl net.ipv4.ip_unprivileged_port_start

Output should be:

    net.ipv4.ip_unprivileged_port_start = 80

<br/>

---

<br/>

### This page is still under construction!
