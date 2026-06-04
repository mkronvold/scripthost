# Install with Docker

This uses the stock `caddy:2-alpine` image. No custom image build is required for normal testing.

This public repo does not include served scripts or artifacts. Mount them from local or private paths at runtime.

## Run

```bash
docker run --rm -p 8080:8080 \
  -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v /path/to/private/scripts:/srv/scripts:ro \
  -v /path/to/published/build:/srv/build:ro \
  caddy:2-alpine \
  caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
```

For local testing, those mounts can point at local working directories. For shared use, mount a curated public artifact tree instead.

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
