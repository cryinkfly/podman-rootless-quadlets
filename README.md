# Rootless Podman service configurations using Quadlets for homelab setups. 📦

## Features
- Rootless container setup
- Systemd-managed containers with Quadlet
- Ready-to-use templates for .container, .network, and .env
- Tested on Raspberry Pi 5 with Debian Trixi
- As an example, the nginx proxy manager is set up here, and SELinux is not installed.

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

[Container]
ContainerName=nginx-proxy-manager
Image=docker.io/jc21/nginx-proxy-manager:latest

AutoUpdate=registry


# Ports
PublishPort=8080:80
PublishPort=8443:443
PublishPort=8081:81

# Volumes
Volume=nginx-proxy-manager_data:/data
Volume=nginx-proxy-manager_letsencrypt:/etc/letsencrypt

# Environment
Environment=TZ=Europe/Berlin

# Networks
Network=proxy

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


Example of creating a custom storage directory:

    mkdir -p /path/to/storage/volumes/nginx-proxy-manager_data
    mkdir -p /path/to/storage/volumes/nginx-proxy-manager_letsencrypt


Or you repare the directories on a separate mounted SSD for example: /mnt/ssd

```
sudo mkdir -p /mnt/ssd/podman/volumes/
#Rootless Podman must be able to write, so create the directories as your user (chwon):
sudo chown -R $(whoami):$(whoami) /mnt/ssd/podman/volumes
sudo chmod -R 755 /mnt/ssd/podman/volumes
mkdir -p /mnt/ssd/podman/volumes/nginx-proxy-manager_data
mkdir -p /mnt/ssd/podman/volumes/nginx-proxy-manager_letsencrypt
```

```
# Optional - For rootless Podman, make sure your user owns the directory:
chown -R $(whoami):$(whoami) /mnt/ssd/podman/volumes/nginx-proxy-manager_data
chown -R $(whoami):$(whoami) /mnt/ssd/podman/volumes/nginx-proxy-manager_letsencrypt
chmod -R 755 /mnt/ssd/podman/volumes/nginx-proxy-manager_data
chmod -R 755 /mnt/ssd/podman/volumes/nginx-proxy-manager_letsencrypt
```

Creates the new Podman volumes with persist container data outside the container filesystem.

```
podman volume create --opt type=none --opt device=/mnt/ssd/podman/volumes/nginx-proxy-manager_data --opt o=bind,rw nginx-proxy-manager_data
podman volume create --opt type=none --opt device=/mnt/ssd/podman/volumes/nginx-proxy-manager_letsencrypt --opt o=bind,rw nginx-proxy-manager_letsencrypt
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

Solution: Use port forwarding with iptables or map to higher ports and forward:

Example: Map 8080 → 80 and 8443 → 443

    sudo nano /etc/systemd/system/rootless-port-forward.service

```
[Unit]
Description=Port Forwarding for Rootless Podman
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
# Forward HTTP and HTTPS ports to high ports
ExecStart=/sbin/iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
ExecStart=/sbin/iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

# Optional: delete on stop
ExecStop=/sbin/iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
ExecStop=/sbin/iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

AutoUpdate=registry

[Install]
WantedBy=multi-user.target
```

Reload systemd:

    sudo systemctl daemon-reload

Permanently enable and start the rootless-port-forward.service:

    sudo systemctl enable --now rootless-port-forward.service

Check the status of rootless-port-forward.service:

    sudo systemctl status rootless-port-forward.service

<br/>

---

<br/>

### This page is still under construction!
