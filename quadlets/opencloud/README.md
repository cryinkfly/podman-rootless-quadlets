    podman network create network proxy-opencloud
    
    podman network connect network proxy-opencloud nginx-proxy-manager

    curl -L https://raw.githubusercontent.com/cryinkfly/podman-rootless-quadlets/main/quadlets/opencloud/opencloud.container -o ~/.config/containers/systemd/opencloud.container

    systemctl --user daemon-reload
    systemctl --user start opencloud.service

💡 Important:

- Nginx Proxy Manager and Radicale (including their configurations) must be fully set up before starting OpenCloud, otherwise OpenCloud cannot correctly reach the CalDAV/CardDAV routes.
- All containers (OpenCloud, Radicale, NPM) must be in the same network (proxy-opencloud) so that internal DNS names like radicale resolve correctly.
- Ports in NPM must be properly forwarded (443/80/81), otherwise HTTPS access will not work.
- Look also here: https://github.com/opencloud-eu/opencloud-compose/issues/192

---
    podman volume create opencloud_config
    podman unshare nano /home/$USER/.local/share/containers/storage/volumes/opencloud_config/_data/csp.yaml

    podman unshare nano /home/$USER/.local/share/containers/storage/volumes/opencloud_config/_data/proxy.yaml

    podman unshare nano /home/$USER/.local/share/containers/storage/volumes/opencloud_config/_data/banned-password-list.txt


... Still in progress ...
