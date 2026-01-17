# FileBrowser Quantum with Radicale Support!

> These settings must be copied into the Nginx Proxy Manager under the advanced file browser settings for radicale to work. 
> Additionally, the [config](https://raw.githubusercontent.com/cryinkfly/podman-rootless-quadlets/refs/heads/main/quadlets/filebrowser-quantum/radicale/config) file from this repository must be moved to the correct source in the Radicale container and created for each user (web frontend).
>
> Video tutorial coming soon!

<img width="1977" height="1620" alt="npm-settings-radicale" src="https://github.com/user-attachments/assets/0c80cf14-6d33-4410-ab1e-ecb314b37156" />

⚠️ It's important that NPM, Radicale, and FileBrowser Quantum are on the same network!

---

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
Edit the radicale `config` file. For example:

```
podman unshare nano /home/$USER/.local/share/containers/storage/volumes/radicale_config/_data/config
```
