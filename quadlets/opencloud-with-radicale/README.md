    podman network create network proxy-opencloud
    
    podman network connect network proxy-opencloud nginx-proxy-manager

    curl -L https://raw.githubusercontent.com/cryinkfly/podman-rootless-quadlets/main/quadlets/opencloud-with-radicale/opencloud.container -o ~/.config/containers/systemd/opencloud.container

    systemctl --user daemon-reload
    systemctl --user start opencloud.service

💡 Important:

- Nginx Proxy Manager and Radicale (including their configurations) must be fully set up before starting OpenCloud, otherwise OpenCloud cannot correctly reach the CalDAV/CardDAV routes.
- All containers (OpenCloud, Radicale, NPM) must be in the same network (proxy-opencloud) so that internal DNS names like radicale resolve correctly.
- Ports in NPM must be properly forwarded (443/80/81), otherwise HTTPS access will not work.
- Look also here: https://github.com/opencloud-eu/opencloud-compose/issues/192

---

Create the following secrets: 

    # echo -n 'password123' | podman secret create opencloud_smtp_pwd -


---

After the first successful start of all containers, the `proxy.yaml` file should be created, and the content from the repository copied and adjusted... except for `proxy.yaml`, as the radical part there is already correct. The `banned-password-list.txt` file is optional.

```
podman unshare nano /home/$USER/.local/share/containers/storage/volumes/opencloud_config/_data/proxy.yaml
```
```
podman unshare nano /home/$USER/.local/share/containers/storage/volumes/opencloud_config/_data/banned-password-list.txt
```

### WARNING:

> Removing a user in OpenCloud does not automatically delete related calendar or address book data. These files remain in the Radicale volume and must be removed manually.

    podman unshare rm -rf /home/$USER/.local/share/containers/storage/volumes/radicale_data/_data/collections/collection-root/USER-HASH-FOLDER

... Still in progress ...
