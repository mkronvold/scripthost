# Add content

`scripthost` serves two kinds of content:

1. scripts from `/srv/scripts`
2. artifacts from `/srv/build`

## Add scripts

This public repo intentionally does not track served scripts.

Place private or local static scripts in a separate directory and mount it to:

```text
/srv/scripts
```

They will be served as:

```text
/script/<filename>
```

Current examples:

- `/script/install`
- `/script/install_wsl`
- `/script/install_local`

## Dynamic dispatcher script

If you use an `install` dispatcher script, it should be rendered by Caddy templates so it can inject the request base URL.

Keep this line template-based:

```bash
BASE_URL="{{placeholder "http.request.scheme"}}://{{.Req.Host}}"
```

Do not replace it with a hardcoded URL.

## Add artifacts

This public repo intentionally does not track published artifacts.

Artifacts are served from the mounted build volume under:

```text
/build/...
```

Your scripts define which paths under `/build/...` they fetch.

## Make a new install flow

To add another installer:

1. add a new script in your private or local scripts directory
2. make it fetch the files it needs from `/build/...`
3. if needed, update your `install` dispatcher to route to it
4. if used in Kubernetes, recreate the `scripthost-scripts` ConfigMap

## Keep it generic

The host itself should stay generic:

- Caddy config in `Caddyfile`
- scripts in mounted `/srv/scripts`
- published artifacts in `/srv/build`

Application-specific logic belongs in the scripts, not in the server container.
