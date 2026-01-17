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
<img width="3806" height="1949" alt="create-user-api-token-radicale" src="https://github.com/user-attachments/assets/fedc155f-48b4-4a7b-a457-572e330c4698" />

---

## And here's another example of adding accounts under Gnome Online (Linux)

<img width="1184" height="1729" alt="gnome-online-add-carldav" src="https://github.com/user-attachments/assets/3adb2f46-be20-4f97-abe6-c83971491af7" />
<img width="1473" height="1636" alt="gnome-online-add-carddav" src="https://github.com/user-attachments/assets/3ba01462-d04c-4b2c-b51a-77b6dc6eabd9" />
<img width="1473" height="1636" alt="gnome-online-settings-carldav" src="https://github.com/user-attachments/assets/e185cf2b-aa6a-434d-95c7-354bde777b55" />
<img width="1473" height="1636" alt="gnome-online-settings-carddav" src="https://github.com/user-attachments/assets/1ecd0044-e591-4b75-8c84-2387f7c9e138" />
<img width="1760" height="957" alt="calender-login" src="https://github.com/user-attachments/assets/34d6a7b2-2d16-4171-ac3b-5525e759fe6b" />
<img width="3806" height="1949" alt="gnome-calendar-with-radicale-sync" src="https://github.com/user-attachments/assets/686c5174-ab55-449e-8123-32692254d676" />
<img width="2157" height="1512" alt="Bildschirmfoto vom 2026-01-17 11-43-12" src="https://github.com/user-attachments/assets/c5387925-19a3-4373-89e3-7d9a51d580df" />
<img width="1954" height="790" alt="Bildschirmfoto vom 2026-01-17 11-42-57" src="https://github.com/user-attachments/assets/02986611-a974-4664-aa47-0553a371c14d" />
<img width="1845" height="236" alt="podman-radicale-ls-calendar-test" src="https://github.com/user-attachments/assets/7cb8fe9b-5f0d-40e7-9945-fe66b9f859dd" />


