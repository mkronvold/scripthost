# Install in Kubernetes

This deployment uses the stock `caddy:2-alpine` image and mounts config, scripts, and artifacts at runtime.

## Create ConfigMaps

```bash
kubectl create configmap scripthost-caddyfile \
  --from-file=Caddyfile=Caddyfile

kubectl create configmap scripthost-scripts \
  --from-file=install=/path/to/private/scripts/install \
  --from-file=install_wsl=/path/to/private/scripts/install_wsl \
  --from-file=install_local=/path/to/private/scripts/install_local
```

The script ConfigMap is built from private or local served content, not from this public repo.

## Provide the build volume

The deployment expects a read-only volume at `/srv/build` via the PVC named `scripthost-build`.

That volume must be populated by another process with whatever published artifact tree your scripts expect.

## Deploy

```bash
kubectl apply -f kubernetes/deployment.yaml
```

This creates:

- a `Deployment` named `scripthost`
- a `Service` named `scripthost`

## Verify

```bash
kubectl port-forward deploy/scripthost 8080:8080
curl -fsSL http://127.0.0.1:8080/healthz
curl -fsSL http://127.0.0.1:8080/script/install
```

## Expose externally

Expose the service with your normal Ingress or load-balancer pattern. The Caddy config already trusts private proxy ranges so the install template can respect forwarded scheme headers from an internal proxy path.
