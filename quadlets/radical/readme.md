# Radicale Rootless Podman Setup

This repository provides a rootless Podman setup for **Radicale**, a simple CalDAV (calendar) and CardDAV (contact) server.  
It uses the **official Radicale image** from Kozea on GHCR, with persistent data and read-only configuration.

---

## Features

- Rootless Podman container
- Persistent data stored in a Podman volume (`radicale_data`)
- Configuration stored in a read-only Podman volume (`radicale_config`)
- User authentication via `htpasswd`
- Minimal Alpine base with Python dependencies included
- Configurable via external config file

---

### 1. Prepare Volumes

For example the volumes are stored here:

> $HOME/.local/share/containers/storage/volumes/radicale_data<br/>
> $HOME/.local/share/containers/storage/volumes/radicale_config


```bash
podman volume create radicale_data
podman volume create radicale_config
```

### 2. Download Example Configuration with activated htpasswd

```bash
curl -o ~/.local/share/containers/storage/volumes/radicale_config/_data/config \
https://raw.githubusercontent.com/cryinkfly/podman-rootless-quadlets/main/quadlets/radical/config
```

> For more information look here: https://radicale.org/v3.html#configuration

### 3. Create Users with htpasswd

We recommend using a temporary container for htpasswd:

```bash
podman run --rm -it \
  -v ~/.local/share/containers/storage/volumes/radicale_config/_data:/data \
  docker.io/httpd:alpine htpasswd -b -c /data/users user1 123456
```

Adds user1 with password 123456
Repeat for additional users (omit -c for additional entries)

The htpasswd file is stored in:

> $HOME/.local/share/containers/storage/volumes/radicale_config/_data/users

And with this command you can see the content of this new file:

```bash
cat ~/.local/share/containers/storage/volumes/radicale_config/_data/users
```

This is the ouput what you get:

```bash
user1:$apr1$gNWIMK5l$PjU8DhFDI0fW7mZyJB4Ki.
```

Explanation:

> user1 → username<br/>
> $apr1$gNWIMK5l$PjU8DhFDI0fW7mZyJB4Ki. → password hashed using Apache MD5 ($apr1$).

Radicale uses this hash for authentication; the actual password (123456) is not stored in plain text.

### 4. Set Permissions on Config Volume

Ensure your user owns the configuration files to edit them outside the container:

```bash
sudo chown -R $(whoami):$(whoami) ~/.local/share/containers/storage/volumes/radicale_config/_data
```

This allows safe editing of config or users without using a temporary container for htpasswd. 

Only needed once after creating the volume or downloading the configuration.

### 5. Download the systemd container unit

```bash
curl -o ~/.config/containers/systemd/radicale.container \
https://raw.githubusercontent.com/cryinkfly/podman-rootless-quadlets/refs/heads/main/quadlets/radical/radicale.container
```

### 6. Enable and start Radicale

```bash
systemctl --user daemon-reload
systemctl --user start radicale.container
```

### 5. Accessing Radicale

- Open in your browser: [http://localhost:5232](http://localhost:5232)
- Or use the server’s IP, for example: `http://192.168.192.20:5232`

- **Note:** The configuration inside the container is **read-only** (`:ro`).  
  Edit the config file **outside the container** if you need to change authentication, rights, or SSL/TLS settings.

### 7. Recommendation: Use HTTPS with a Reverse Proxy

For security and easier access, it is recommended to put Radicale behind a reverse proxy such as **Nginx Proxy Manager**:

- Map a public domain (e.g., `calendar.example.com`) to the server IP
- Enable SSL/TLS via Let’s Encrypt (HTTPS)
- Forward requests to the internal Radicale container (`http://localhost:5232`)

This way, your CalDAV/CardDAV server is accessible securely over HTTPS, and you can use custom domains for client synchronization.
