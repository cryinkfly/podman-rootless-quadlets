# FileBrowser Quantum with Radicale Support!

> These settings must be copied into the Nginx Proxy Manager under the advanced file browser settings for radicale to work. 
> Additionally, the [config](https://raw.githubusercontent.com/cryinkfly/podman-rootless-quadlets/refs/heads/main/quadlets/filebrowser-quantum/radicale/config) file from this repository must be moved to the correct source in the Radicale container and created for each user (web frontend).

<img width="1977" height="1620" alt="npm-settings-radicale" src="https://github.com/user-attachments/assets/37c1bacd-bb6d-4153-b282-167f6a3f96c3" />


⚠️ It's important that NPM, Radicale, and FileBrowser Quantum are on the same network!

---

## Configure the cloud.example.org settings in Nginx Proxy Manager

```
# ---------------- CalDAV ----------------
location /caldav/ {
    proxy_pass http://radicale:5232;
    proxy_http_version 1.1;

    # WebDAV Standard Headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Radicale Headers
    proxy_set_header X-Remote-User $remote_user;
    proxy_set_header X-Script-Name /caldav;
}

location /.well-known/caldav {
    proxy_pass http://radicale:5232;
    proxy_set_header Host $host;
    proxy_set_header X-Remote-User $remote_user;
    proxy_set_header X-Script-Name /caldav;
}

# ---------------- CardDAV ----------------
location /carddav/ {
    proxy_pass http://radicale:5232;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_set_header X-Remote-User $remote_user;
    proxy_set_header X-Script-Name /carddav;
}

location /.well-known/carddav {
    proxy_pass http://radicale:5232;
    proxy_set_header Host $host;
    proxy_set_header X-Remote-User $remote_user;
    proxy_set_header X-Script-Name /carddav;
}
```

```
# ---------------- Optional: Web-UI ----------------
location /caldav/.web/ {
    proxy_pass http://radicale:5232/;
    auth_basic off;  # WebUI fragt selbst nach Passwort
    proxy_set_header Host $host;
    proxy_set_header X-Remote-User $remote_user;
    proxy_set_header X-Script-Name /caldav;
}
```

---

## Edit the radicale `config` file. For example:

```
podman unshare nano /home/$USER/.local/share/containers/storage/volumes/radicale_config/_data/config
```

---

## Create an API token for authentication.

<img width="3806" height="1949" alt="Bildschirmfoto vom 2026-01-17 11-28-05" src="https://github.com/user-attachments/assets/a81e822a-457d-4c78-aeec-d9d100f85b77" />
<img width="3806" height="1949" alt="Bildschirmfoto vom 2026-01-17 11-28-13" src="https://github.com/user-attachments/assets/818aa3ad-fa6b-4f75-8977-7bf561ed507a" />

---

## And here's another example of adding accounts under Gnome Online (Linux)

<img width="1845" height="1754" alt="gnome-online-add-carldav-carddav" src="https://github.com/user-attachments/assets/0bc3a827-11f4-4d1a-afc9-09ea84d59df6" />
<img width="1845" height="1571" alt="gnome-online-settings-carldav-carddav" src="https://github.com/user-attachments/assets/204aaae0-4cba-4232-8743-a216c4175875" />
<img width="3806" height="1949" alt="gnome-calendar-with-radicale-sync" src="https://github.com/user-attachments/assets/686c5174-ab55-449e-8123-32692254d676" />
<img width="2157" height="1512" alt="Bildschirmfoto vom 2026-01-17 11-43-12" src="https://github.com/user-attachments/assets/c5387925-19a3-4373-89e3-7d9a51d580df" />
<img width="1954" height="790" alt="Bildschirmfoto vom 2026-01-17 11-42-57" src="https://github.com/user-attachments/assets/02986611-a974-4664-aa47-0553a371c14d" />
<img width="1845" height="236" alt="podman-radicale-ls-calendar-test" src="https://github.com/user-attachments/assets/7cb8fe9b-5f0d-40e7-9945-fe66b9f859dd" />


