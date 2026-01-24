# Rootless Podman with Quadlets 📦

This guide explains how to manage `rootless Podman containers` using `systemd Quadlets`, suitable for Raspberry Pi or other homelab environments.

> **Tested on:** Raspberry Pi 5 with Debian Trixi (Version 13) </br>
> **Podman version:** 5.4.2+  </br>
> **Exposed Ports:** 80/443 (HTTP/HTTPS) and 81 (NPM Admin UI)  </br>
> **SELinux:** Optional (not required)

```
           .--"--.                          .------.      .------.      .------.
         / -     - \                       /      /|    /      /|    /      /|
        / (O)   (O) \                     / Pod1 / |   / Pod2 / |   / Pod3 / |
     ~~~| -=(,Y,)= - |~~~                 '------' |   '------' |   '------' |
      .---. /`  \   |~~                   |      | '  |      | '  |      | '
   ~/  o  o \~~~~.----. ~~                 | C1   |    | C3   |    | C5   |
  | =(X)= |~  / (O (O) \                  | C2   |    | C4   |    | C6   |
   ~~~~~~~  ~| =(Y_)=-  |                  '------'    '------'    '------'
  ~~~~    ~~~|   U      |~~                     ||          ||          ||
                                               ~~||~~~~~~~~~~||~~~~~~~~~~||~~
                                                Network-A  Network-B  Network-C
```

<div align="left">
 <img align="center" src="https://img.shields.io/github/license/cryinkfly/podman-rootless-quadlets?style=flat">
 <img align="center" src="https://img.shields.io/github/last-commit/cryinkfly/podman-rootless-quadlets?style=flat">
 <img align="center" src="https://img.shields.io/github/issues-raw/cryinkfly/podman-rootless-quadlets?style=flat"> 
 <img align="center" src="https://img.shields.io/github/stars/cryinkfly/podman-rootless-quadlets?style=flat"> 
 <img align="center" src="https://img.shields.io/github/forks/cryinkfly/podman-rootless-quadlets?style=flat"> 
</div>

## Features

- Rootless container setup only 
- Systemd-managed containers via Quadlets
- Templates for `.pod`, `.container`, `.network`, `.env`, `...` files
- Persistent storage support – container data survives restarts
- Automatic container updates via timer – uses `podman-auto-update`
- Only ports `80`, `443`, `81` exposed by default
- Safe low port binding with `net.ipv4.ip_unprivileged_port_start=80`
- `Nginx Proxy Manager handles all external access`; containers do not expose extra ports
- Secure secrets support – use Podman Secrets to store `passwords`, `tokens`, `...` without exposing them in environment variables

---

### 1. Check if Podman is installed on the system; if not, install it.

```
command -v podman >/dev/null || sudo apt update && sudo apt install -y podman
```

<img width="968" height="504" alt="grafik" src="https://github.com/user-attachments/assets/e1a37c29-b8e2-4010-b6e5-a5c496526da7" />
<img width="968" height="106" alt="grafik" src="https://github.com/user-attachments/assets/dc5eba14-205e-4fe9-a552-ac611d4a5fb6" />

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
graphroot = "/mnt/podman/data" # Mounted external drive or custom path
```

> Other storage drivers exist (e.g., vfs, btrfs, zfs). See the official Podman documentation for details: https://docs.podman.io/en/v5.4.2/markdown/podman.1.html

For rootless Podman, make sure your user owns the directory on the SSD:

```
chown -R $(whoami):$(whoami) /mnt/podman/data
chmod -R 700 /mnt/podman/data
```

---

### 5 Create a seperate podman network for example the Nginx Proxy Manager

```
podman network create proxy.net
```

Note / Special Considerations:

- This network will be used by `Nginx Proxy Manager` to `handle external access`.
- Later, additional networks can be created for other containers or services (e.g., Vaultwarden, Jellyfin).
- `Nginx Proxy Manager` can `join all networks to reverse proxy requests`, while containers themselves remain isolated by default.
- By default, containers do not communicate with each other unless they are explicitly grouped in a pod. This ensures better security and `network separation` in your homelab setup.

---

### 6. Create a .container and .network file for example the Nginx Proxy Manager

```
nano ~/.config/containers/systemd/proxy.network
```

```
[Unit]
Description=Podman network for Nginx Proxy Manager

# Network dependency is handled via podman-user-wait-network-online.service
# Wants/After network-online.target have no effect for rootless containers
# See: https://github.com/cryinkfly/podman-rootless-quadlets/issues/1

[Network]
NetworkName=proxy.net
```

```
nano ~/.config/containers/systemd/nginx-proxy-manager.container
```

```
[Unit]
Description=Nginx Proxy Manager (Rootless Podman)
# Requires Podman version >= 5.4.2

# Ensure the networks are created and active before starting this container
After=proxy-network.service
Requires=proxy-network.service
BindsTo=proxy-network.service

#After=proxy-network.service vaultwarden-network.service ...
#Requires=proxy-network.service vaultwarden-network.service ...
#BindsTo=proxy-network.service vaultwarden-network.service ...

[Container]
ContainerName=nginx-proxy-manager
Image=docker.io/jc21/nginx-proxy-manager:latest

# Automatical Updates
# To enable automatic updates for all containers, start the systemd timer:
# systemctl --user start --now podman-auto-update.timer
AutoUpdate=registry

# Network Settings
# Isolated container networks
Network=proxy.net
# Connect the nginx-proxy-manager to another networks. For example: vaultwarden.net
# Network=vaultwarden.net
# ...
PublishPort=80:80
PublishPort=443:443
PublishPort=81:81

# Timezone
# This option tells Podman to set the time zone based on the local system's time zone where Podman is running.
Timezone=local

# Volumes
Volume=nginx-proxy-manager_data:/data:Z
Volume=nginx-proxy-manager_letsencrypt:/etc/letsencrypt:Z

# Healthcheck on dashboard port
HealthCmd=["CMD-SHELL", "curl -f http://localhost:81 || exit 1"]
HealthInterval=10s
HealthTimeout=3s
HealthRetries=3
HealthStartPeriod=30s
HealthOnFailure=kill

[Service]
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

---

### 7. Auto-Update Timer

#### Activate the Auto-Update Timer

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

This command shows whether the Podman auto-update timer is active. Later, the logs from the triggered service `podman-auto-update.service` can be used to see which container images were actually updated.

<br/>

Here is an example:

```
systemctl --user status podman-auto-update.service
○ podman-auto-update.service - Podman auto-update service
     Loaded: loaded (/usr/lib/systemd/user/podman-auto-update.service; disabled; preset: enabled)
     Active: inactive (dead) since Fri 2026-01-23 11:00:59 CET; 2min 23s ago
 Invocation: cad47ce6b39f4abcb0b5a3733756c1aa
TriggeredBy: ● podman-auto-update.timer
       Docs: man:podman-auto-update(1)
   Main PID: 15889 (code=exited, status=0/SUCCESS)
        CPU: 1.477s

Jan 23 11:00:54 pod_system podman[15889]: 2026-01-23 11:00:54.72001975 +0100 CET m=+7.853205496 image pull 249e0dbbf2973c92bbf6bd6660ff6d72e838036fc27c5635667793a7895b16c5 ghcr.io/kozea/radicale:latest
Jan 23 11:00:59 pod_system podman[15889]:             UNIT                         CONTAINER                                  IMAGE                                      POLICY      UPDATED
Jan 23 11:00:59 pod_system podman[15889]:             nginx-proxy-manager.service  e3bbf09070ab (nginx-proxy-manager)         docker.io/jc21/nginx-proxy-manager:latest  registry    false
Jan 23 11:00:59 pod_system podman[15889]:             vaultwarden.service          609142eb2224 (vaultwarden)                 docker.io/vaultwarden/server:latest        registry    false
Jan 23 11:00:59 pod_system podman[15889]:             filebrowser-quantum.service  fca9ac3033a5 (filebrowser-quantum-server)  docker.io/gtstef/filebrowser:latest        registry    true
Jan 23 11:00:59 pod_system podman[15889]:             filebrowser-quantum.service  440a5938951b (radicale)                    ghcr.io/kozea/radicale:latest              registry    true
Jan 23 11:00:59 pod_system podman[16090]: 53197fd2f3cda0e6706c616cbe7904f45f26b3b436fdf1f27c31275adfe98aff
Jan 23 11:00:59 pod_system podman[16090]: 2026-01-23 11:00:59.073240421 +0100 CET m=+0.037328026 image remove 53197fd2f3cda0e6706c616cbe7904f45f26b3b436fdf1f27c31275adfe98aff 
Jan 23 11:00:59 pod_system systemd[885]: Finished podman-auto-update.service - Podman auto-update service.
Jan 23 11:00:59 pod_system systemd[885]: podman-auto-update.service: Consumed 1.477s CPU time.
```

---

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

---

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

---

### 10. Start the container

Once your `.container` Quadlet is ready and systemd has been reloaded, start the container:

```
systemctl --user start nginx-proxy-manager.service
```

---

### 11. Check if the Podman Container is Running

Verify that your rootless container is up and running:

```
podman ps
```

---

### 12. Healthcheck for example the Nginx Proxy Manager

You can test whether Nginx Proxy Manager is working correctly:

```
podman inspect -f '{{.State.Health.Status}}' nginx-proxy-manager
```

---

### 13. Podman Secrets: Handling Sensitive Data

`Podman Secrets` allow you to provide sensitive data such as `passwords`, `tokens`, `...` securely to containers without storing them in the `environment variables`.

In this section, we will show how to create a secret, use it in a container, and manage it.

For example we use a Secret for the Vaultwarden admin token

```
Secret=vaultwarden_admin_pwd,type=env,target=ADMIN_TOKEN
```

**Explanation:**

- `vaultwarden_admin_pwd` → Name of the secret you just created
- `type=env` → Passes the secret as an environment variable inside the container
- `target=ADMIN_TOKEN` → Name of the environment variable inside the container

**Steps to use:**

**1. Generate a secure token (e.g., using Argon2):**

You can create your own special token online here: https://argon2.online/

     <img width="1537" height="1149" alt="grafik" src="https://github.com/user-attachments/assets/dc05eea0-462b-4b3c-b66d-325f8e83570b" />

<br/>
 
**2. Create a Podman secret:**

```
echo -n '$argon2i$v=19$m=16,t=2,p=1$MmVuYXZXZU1NblhORXBXaw$BTgzECkgwX+Aw1QvOHug/g' | podman secret create vaultwarden_admin_pwd -
```

<br/>

**3. List all secrets:**

```
podman secret ls
```

<br/>

**4. Remove a secret:**

```
podman secret rm vaultwarden_admin_pwd
```

<br/>

**5. Here can you see more functions:**

```
podman secret --help
Manage secrets

Description:
  Manage secrets

Usage:
  podman secret [command]

Available Commands:
  create      Create a new secret
  exists      Check if a secret exists in local storage
  inspect     Inspect a secret
  ls          List secrets
  rm          Remove one or more secrets
```

---

### 14. Official Podman Documentation

Link: https://podman.io/docs

The official Podman docs provide guides, tutorials, and reference material for using Podman, a daemonless, rootless container engine compatible with Docker commands.

**What you’ll find:**

- Getting Started: Installation, running containers, pulling images
- Command Reference & Tutorials: Full CLI reference, advanced usage, API docs
- Networking & Pods: Container networking, pods, checkpointing, migration
- Python SDK: Using Podman in Python scripts

Podman is a modern container tool that doesn’t require a central daemon, supports rootless containers, and works well for development, testing, and production.

---

### Support this project, share your ideas, and help our community thrive! ♥️ 

If you enjoy my work and want to help me create more tutorials, guides, and open-source projects, you can **support me in multiple ways** — either as a sponsor or as an active helper!  

**Ways to Support:**  
- 💰 **Sponsors:** Contribute financially to help cover hosting costs, development time, and resources  
- 🤝 **Supporters & Collaborators:** Share ideas, provide feedback, contribute tutorials or code, and help the community grow  

**Benefits of Supporting:**  
- 💡 Early access to new tutorials and resources  
- 🔒 Exclusive updates and behind-the-scenes insights  
- 🏅 Recognition on the website or in projects (optional)  
- 🌱 Helping the community thrive and learn together

**Support my work, contribute ideas, and help the community grow!**

[![Become a Sponsor or Supporter](https://img.shields.io/badge/Become%20a%20Sponsor%20or%20Supporter-%23E34C4C?style=for-the-badge&logoColor=white)](https://cryinkfly.com/sponsors)
