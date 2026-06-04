# scripthost

`scripthost` is a generic HTTP script host built around the stock `caddy:2-alpine` image.

This public repository contains the host configuration, deployment manifests, and documentation only.

Served content is intentionally not committed here:

- private or local scripts should be mounted to `/srv/scripts`
- published artifacts should be mounted to `/srv/build`

Docs:

- [INSTALL_DOCKER.md](INSTALL_DOCKER.md)
- [INSTALL_K8S.md](INSTALL_K8S.md)
- [ADD_CONTENT.md](ADD_CONTENT.md)
- [SECURITY.md](SECURITY.md)

Kubernetes script/build updates are applied from generated ConfigMaps and can then either restart the deployment or push content directly into running pod storage.
