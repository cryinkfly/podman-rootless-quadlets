# FileBrowser Quantum with Radicale Support!

> These settings must be copied into the Nginx Proxy Manager under the advanced file browser settings for radicale to work. 
> Additionally, the [config](https://raw.githubusercontent.com/cryinkfly/podman-rootless-quadlets/refs/heads/main/quadlets/filebrowser-quantum/radicale/config) file from this repository must be moved to the correct source in the Radicale container and created for each user (web frontend).

⚠️ It's important that NPM, Radicale, and FileBrowser Quantum are on the same network!

---

## Configure the cloud.example.org settings in Nginx Proxy Manager

> In my setup, the `Radicale container runs inside the filebrowser-quantum pod` (filebrowser-quantum.pod).
> Since all containers inside a Podman pod share the same network namespace, Radicale is not reachable by its own container name (radicale) from outside the pod.
> Instead, it must be accessed via the pod name.

| Domain            | Target Container    | SSL           | Access | Port | Status |    |
|-------------------|---------------------|---------------|--------|------|--------|--- |
| cloud.example.org | filebrowser-quantum | Let's Encrypt | Puplic |  80  | Online | ⚙️ |

>⚙️ Indicates that the proxy settings, including custom locations, etc. are configured under the “Locations” tab in the NPM GUI.

---

| Location          | Schema | Forward Hostname / IP    | Forward Port  |    |
|-------------------|--------|--------------------------|---------------|--- |
| /caldav/          | http   | filebrowser-quantum      | 5232          | ⚙️ |

```
proxy_set_header X-Script-Name /caldav;
proxy_set_header X-Remote-User $remote_user;
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
```

---

| Location          | Schema | Forward Hostname / IP    | Forward Port  |    |
|-------------------|--------|--------------------------|---------------|--- |
| /carddav/         | http   | filebrowser-quantum      | 5232          | ⚙️ |

```
proxy_set_header X-Script-Name /caldav;
proxy_set_header X-Remote-User $remote_user;
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
```

---

| Location          | Schema | Forward Hostname / IP    | Forward Port  |    |
|-------------------|--------|--------------------------|---------------|--- |
| /.well-known/carldav         | http   | filebrowser-quantum      | 5232          | ⚙️ |

```
return 301 /carldav/;
```

---

| Location          | Schema | Forward Hostname / IP    | Forward Port  |    |
|-------------------|--------|--------------------------|---------------|--- |
| /.well-known/carddav         | http   | filebrowser-quantum      | 5232          | ⚙️ |

```
return 301 /carddav/;
```

---

If the `Radicale container runs outside of the filebrowser-quantum pod`, for example as its own container or pod:

- Radicale must be attached to the same Podman network as Nginx Proxy Manager
(e.g. filebrowser-quantum.net or proxy.net)
- In this case, Radicale can be resolved via its container name
his ensures NPM waits for FileBrowser to be active before starting.

As a result, the custom locations (cloud.example.org → filebrowser-quantum:80) resolve correctly on startup.

Then the upstream address becomes:

```
http://radicale:5232
```

---

## Edit the radicale `config` file. For example:

```
podman unshare nano /home/$USER/.local/share/containers/storage/volumes/radicale_config/_data/config
```

---

## Create an API token for authentication.

<img width="3806" height="1949" alt="Bildschirmfoto vom 2026-01-17 11-28-05" src="https://github.com/user-attachments/assets/a81e822a-457d-4c78-aeec-d9d100f85b77" />
<img width="3806" height="1949" alt="create-user-api-token-radicale" src="https://github.com/user-attachments/assets/fedc155f-48b4-4a7b-a457-572e330c4698" />

### 💡 Notice: The API-Tokens can be recreated at any time, or a separate API-Token can be created for each client! For exeample: Thunderbird, Evolution, ...

---

## And here's another example of adding accounts under Gnome Online (Linux)

<img width="1184" height="1729" alt="gnome-online-add-carldav" src="https://github.com/user-attachments/assets/3adb2f46-be20-4f97-abe6-c83971491af7" />
<img width="1473" height="1636" alt="gnome-online-add-carddav" src="https://github.com/user-attachments/assets/3ba01462-d04c-4b2c-b51a-77b6dc6eabd9" />
<img width="1473" height="1636" alt="gnome-online-settings-carldav" src="https://github.com/user-attachments/assets/e185cf2b-aa6a-434d-95c7-354bde777b55" />
<img width="1473" height="1636" alt="gnome-online-settings-carddav" src="https://github.com/user-attachments/assets/1ecd0044-e591-4b75-8c84-2387f7c9e138" />
<img width="1760" height="957" alt="calender-login" src="https://github.com/user-attachments/assets/34d6a7b2-2d16-4171-ac3b-5525e759fe6b" />
<img width="3806" height="1949" alt="gnome-calendar-with-radicale-sync" src="https://github.com/user-attachments/assets/686c5174-ab55-449e-8123-32692254d676" />
<img width="1954" height="790" alt="Bildschirmfoto vom 2026-01-17 11-42-57" src="https://github.com/user-attachments/assets/02986611-a974-4664-aa47-0553a371c14d" />
<img width="2157" height="1512" alt="Bildschirmfoto vom 2026-01-17 11-43-12" src="https://github.com/user-attachments/assets/c5387925-19a3-4373-89e3-7d9a51d580df" />
<img width="1845" height="236" alt="podman-radicale-ls-calendar-test" src="https://github.com/user-attachments/assets/7cb8fe9b-5f0d-40e7-9945-fe66b9f859dd" />

---

## 👤 List all users (usernames/nicknames) who have any collection (CarlDav & CardDav)


```
podman unshare ls -1 /home/$USER/.local/share/containers/storage/volumes/radicale_data/_data/collections/collection-root \
  | grep -v '^admin$'
```

Example output:

- lisa
- max

## 💾 Backup a user collection (CarlDav & CardDav)

```
podman unshare cp -a \
  /home/$USER/.local/share/containers/storage/volumes/radicale_data/_data/collections/collection-root/lisa \
  ~/radicale-backups/
```

## 🔥 Delete a user collection (CarlDav & CardDav)

And if, for example, Lisa is deleted from the Quantum file browser, the data in Radicale remains unchanged. This is a security feature.

However, if Lisa is deleted from the Quantum file browser and you are certain that Lisa's data can and should also be deleted from Radicale, then you can do so with the following command:

```
podman unshare rm -rf /home/$USER/.local/share/containers/storage/volumes/radicale_data/collections/collection-root/lisa
```

---

## 🔥 Troubleshooting with Nginx Proxy Manager as Proxy

When using Nginx Proxy Manager (NPM) to proxy a domain such as:

| Domain            | Target Container    | SSL           | Access | Port | Status |    |
|-------------------|---------------------|---------------|--------|------|--------|--- |
| cloud.example.org | filebrowser-quantum | Let's Encrypt | Puplic |  80  | Online | ⚙️ |

> **⚙️** → Indicates that the settings for this proxy (custom locations, etc.) can be configured via the **Nginx Proxy Manager GUI**.

While these custom locations work in the GUI, you may encounter issues after restarting NPM. Although NPM itself starts, the proxy to FileBrowser may fail, often returning 502 or 504 errors.


### Cause

- FileBrowser Quantum runs inside a Podman pod (filebrowser-quantum.pod).
- NPM relies on the internal hostname filebrowser-quantum for its custom locations.
- If NPM starts before the Pod or FileBrowser container is running, it cannot resolve the hostname, causing the proxy to fail.
- This typically occurs during system boot or when NPM is restarted independently.

### Solution

Since your FileBrowser Quantum pod has its [Install] section with:

```
WantedBy=default.target
```

... this means systemd automatically starts the pod at user login/boot.

**Consequently:**

- You do not need Nginx Proxy Manager to wait for FileBrowser via `After=` or `Requires=`, because the pod is already guaranteed to be running by the time the user session starts.
- Adding `After=filebrowser-quantum.service` in NPM causes the circular dependency problem you saw.
- NPM can safely start immediately, and as long as the pod is running, its internal hostname (filebrowser-quantum) is resolvable, so your Custom Locations in NPM GUI will work.

💡 **Key takeaway:**

- Let the pod handle its own startup via `WantedBy=default.target`, and avoid systemd dependencies from NPM → this prevents deadlocks while ensuring proper resolution of container hostnames.
