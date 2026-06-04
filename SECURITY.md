# Security

## Current model

`scripthost` serves installer scripts and published artifacts over HTTP using stock Caddy.

This public repo intentionally excludes served scripts and published artifacts. Those are mounted at runtime from private or local sources.

It is designed for simple internal use, but it still needs basic guardrails.

## Recommended controls

1. mount config, scripts, and build content read-only
2. publish only curated files in the mounted `/srv/build` tree
3. do not put secrets, private keys, tokens, or internal-only config into `/srv/build`
4. restrict network exposure to trusted internal users or networks
5. terminate TLS at an ingress or proxy when exposing it beyond a trusted internal segment

## Why the Caddyfile looks like this

- `admin off` disables the Caddy admin API
- `auto_https off` avoids unwanted certificate automation for internal or test deployments
- `trusted_proxies static private_ranges` lets the install template respect forwarded scheme headers from internal proxies

## Template safety

The dispatcher at `/script/install` is rendered dynamically by Caddy templates so it can set the correct `BASE_URL`.

That means:

- `install` is intentionally templated
- `install_wsl` and `install_local` are static scripts

Do not add secrets to templated content. Treat everything served here as public to the intended audience.

## Artifact publishing

The safest model is to mount a purpose-built public artifact tree into `/srv/build`, not an arbitrary full filesystem tree.

## Curl-pipe-bash risk

The intended workflow uses:

```bash
curl -fsSL 'http://HOST:8080/script/install' | sudo bash
```

That is convenient, but high trust by design. Only use it from a trusted host and trusted publishing path. If you need stronger change control, publish versioned scripts and artifacts and review them before execution.
