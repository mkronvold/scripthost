# Install in Kubernetes

This deployment uses the stock `caddy:2-alpine` image and mounts config, scripts, and artifacts at runtime.

## Create ConfigMaps

```bash
./deploy.sh
```

By default `deploy.sh` uses:

- `CADDYFILE=$PWD/Caddyfile`
- `SCRIPTS_DIR=$PWD/scripts`
- `BUILD_DIR=$PWD/build`
- `CONFIGMAP_YAML=$PWD/configmap.yaml`
- `BUILD_CONFIGMAP_YAML=$PWD/build-configmap.yaml`
- `APP_NAME=scripthost`
- `NAMESPACE=default`
- `IMAGE=caddy:2-alpine`

The script ConfigMap is generated from local `scripts/` content into `configmap.yaml`, then applied from that generated file.
The build ConfigMap is generated from local `build/` content into `build-configmap.yaml`, then applied from that generated file.

## Pod storage

The deployment runs Caddy with `--watch`, so mounted `Caddyfile` changes are reloaded automatically.
During deployment, the Caddyfile, scripts, and build content are seeded from ConfigMaps into writable `emptyDir` volumes at `/etc/caddy`, `/srv/scripts`, and `/srv/build`.

After you apply an updated script or build ConfigMap, the helper scripts can:

1. restart the deployment so fresh pods reseed from the updated ConfigMaps
2. push the local files directly into the currently running pod storage
3. leave the running pods unchanged

## Push a live Caddyfile update

```bash
./updatecaddyfile.sh
```

`updatecaddyfile.sh`:

- updates the `${APP_NAME}-caddyfile` ConfigMap from the local `./Caddyfile`
- copies the local `./Caddyfile` into each running pod at `/etc/caddy/Caddyfile`
- prints a success message noting that Caddy `--watch` will reload the change automatically

## Verify

```bash
kubectl port-forward deploy/scripthost 8080:8080
curl -fsSL http://127.0.0.1:8080/healthz
curl -fsSL http://127.0.0.1:8080/script/install
```

## Add or update scripts

```bash
./addscript.sh my-script
```

By default `addscript.sh`:

- creates `./scripts/` if it does not exist yet
- copies the file into `./scripts/`
- sets mode `0555`
- regenerates `configmap.yaml`
- warns if the generated ConfigMap may be too large
- asks whether to run `updatescriptconfigmap.sh`

Override with env vars if needed:

```bash
SCRIPTS_DIR=/path/to/scripts ./addscript.sh /path/to/script
```

## Regenerate or apply the scripts ConfigMap

```bash
./updatescriptconfigmap.sh
```

`updatescriptconfigmap.sh`:

- reads all local files in `./scripts/`
- generates `./configmap.yaml`
- warns when the generated ConfigMap may be too large
- asks whether to apply it to the cluster
- after apply, asks whether to restart the deployment, push the updated scripts into running pod storage, or do neither

## Add or update build content

```bash
./addbuild.sh /path/to/k8s-login usr/local/bin/k8s-login
./addbuild.sh /path/to/k8s-login.conf etc/k8s-login.conf
```

By default `addbuild.sh`:

- creates `./build/` if it does not exist yet
- copies the file into local `./build/`
- preserves the relative destination path you provide
- regenerates `build-configmap.yaml`
- warns if the file or generated ConfigMap may be too large
- asks whether to run `updatebuildconfigmap.sh`

## Regenerate or apply the build ConfigMap

```bash
./updatebuildconfigmap.sh
```

`updatebuildconfigmap.sh`:

- archives local `./build/`
- generates `./build-configmap.yaml`
- warns when the archive or generated ConfigMap may be too large
- asks whether to apply it to the cluster
- after apply, asks whether to restart the deployment, push the updated build content into running pod storage, or do neither

## Remove

```bash
./remove.sh
```

Override `APP_NAME` and `NAMESPACE` if needed:

```bash
APP_NAME=my-scripthost NAMESPACE=tools ./deploy.sh
APP_NAME=my-scripthost NAMESPACE=tools ./remove.sh
```
