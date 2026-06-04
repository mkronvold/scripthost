# Install with Docker

This uses the stock `caddy:2-alpine` image. No custom image build is required for normal testing.

This public repo does not include served scripts or artifacts. Mount them from local or private paths at runtime.

## Run

```bash
./up.sh
```

By default `up.sh` uses:

- `CADDYFILE=$PWD/Caddyfile`
- `SCRIPTS_DIR=$PWD/scripts`
- `BUILD_DIR=$PWD/build`

If those default repo-local `scripts/` or `build/` directories do not exist yet, `up.sh` creates empty ones automatically. If you override either path, the override must already exist.

It starts Caddy with `--watch`, so local changes to the mounted `Caddyfile` auto-reload.

Override them as needed:

```bash
SCRIPTS_DIR=/path/to/private/scripts BUILD_DIR=/path/to/published/build ./up.sh
```

## Test

```bash
curl -fsSL http://HOST:8080/healthz
curl -fsSL http://HOST:8080/
curl -fsSL http://HOST:8080/script/install
```

## Installer example

```bash
curl -fsSL 'http://HOST:8080/script/install' | sudo bash
```

## Optional wrapper image

`Dockerfile` is only a convenience wrapper around stock Caddy. It still expects `/srv/scripts` and `/srv/build` to be mounted at runtime:

```bash
docker build -t scripthost .
docker run --rm -p 8080:8080 \
  -v /path/to/private/scripts:/srv/scripts:ro \
  -v /path/to/published/build:/srv/build:ro \
  scripthost
```

## Stop

```bash
./down.sh
```
