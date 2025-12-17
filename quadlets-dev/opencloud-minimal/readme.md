# OpenCloud (Rootless Podman + systemd)

This guide describes how to run **OpenCloud** using **rootless Podman** with a **systemd user service**.

---

## 1. Create required volumes (one time)

```bash
podman volume create opencloud_config
podman volume create opencloud_data
```

---

## 2. Initial setup (REQUIRED – run once)

⚠️ **OpenCloud must be initialized before the systemd service can start.**

```bash
podman run --rm -it \
  -v opencloud_config:/etc/opencloud \
  -v opencloud_data:/var/lib/opencloud \
  -e IDM_ADMIN_PASSWORD=admin \
  docker.io/opencloudeu/opencloud-rolling:latest init
```

---

## 3. Create the systemd container unit

Create the file:

```bash
nano ~/.config/containers/systemd/opencloud.container
```

Content:

```ini
[Unit]
Description=OpenCloud (Rootless Podman)

[Container]
ContainerName=opencloud
Image=docker.io/opencloudeu/opencloud-rolling:latest

# HTTP-Port für OpenCloud
# Use server's LAN IP for external access with an nginx-proxy manager for example.
# Or use 127.0.0.1/localhost if the browser is on the same machine as the container.
PublishPort=127.0.0.1:9200:9200

# Mounts for existing Docker volumes
Volume=opencloud_config:/etc/opencloud
Volume=opencloud_data:/var/lib/opencloud

# Environment
# Disable certificate checking (not recommended for public instances)
Environment=OC_INSECURE=true
Environment=PROXY_HTTP_ADDR=0.0.0.0:9200

# URL for OpenCloud access: use localhost only if accessing from the same machine,
# otherwise set your domain or the server's LAN IP for external access with an nginx-proxy manager for example.
Environment=OC_URL=https://127.0.0.1:9200 # or https://opencloud.example.org

# Network (same as reverse proxy) - Optional
Network=proxy

[Service]
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

---

## 4. Start OpenCloud via systemd (rootless)

```bash
systemctl --user daemon-reload
systemctl --user start opencloud.service
```

---

## 5. Access OpenCloud

* **Direct (HTTPS)**
  [https://192.168.200.15:9200](https://127.0.0.1:9200)

* **Via reverse proxy (HTTPS)**
  [https://opencloud.example.org](https://opencloud.example.org)

---

## Important notes

* **Initialization is mandatory** – without `init` the container will exit immediately.
* `PROXY_HTTP_ADDR=0.0.0.0:9200` is required so OpenCloud listens on the container port.
* `OC_URL` must match the public URL used by the browser or reverse proxy.
* Rootless Podman **cannot bind directly to port 443**.
