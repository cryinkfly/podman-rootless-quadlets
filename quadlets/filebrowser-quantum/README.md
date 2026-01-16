Create a volume for the `config.yaml` and `database.db`

    podman volume create filebrowser-quantum_data

Download the `config.yaml`

    curl -fsSL https://raw.githubusercontent.com/cryinkfly/podman-rootless-quadlets/main/quadlets/filebrowser-quantum/config.yaml -o /home/$USER/.local/share/containers/storage/volumes/filebrowser-quantum_data/_data/config.yaml

With this command you can edit the config.yaml after startup the container:

    podman unshare nano /home/$USER/.local/share/containers/storage/volumes/filebrowser-quantum_data/_data/config.yaml
