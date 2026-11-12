# Publishing one hostname both internally and on the internet

The goal: `x.${EXTERNAL_DOMAIN}` resolves on the LAN to Traefik directly, and
also works from the internet through the cloudflared tunnel — one hostname, one
publicly-trusted certificate, and only for the hosts that opt in.

## How the two halves work

**Internal.** The existing external-dns (`../external-dns`) writes A records into
UniFi and has no `domainFilters`, so it already manages any host it sees on an
ingress — `${EXTERNAL_DOMAIN}` ones included. pihole's single upstream is the
UniFi gateway, which answers local records and recurses everything else:

```
@pihole epg.home       -> 192.168.10.171    answered locally
@pihole borgs.net      -> 104.21.89.176     recursed to Cloudflare
```

So one host gets a LAN answer while every other name in the zone still resolves
publicly. No conditional forwards, no per-host pihole lines.

**External.** This instance creates a proxied CNAME in Cloudflare pointing at
`<tunnel-id>.cfargotunnel.com`, but only for ingresses carrying
`external-dns.alpha.kubernetes.io/publish-public: "true"`. cloudflared then
delivers the request to the main Traefik.

**Certificate.** `letsencrypt` (see `cluster/core/cert-manager/`) issues via
DNS-01, so it never needs inbound port 80 and works for internal-only hosts too.
One cert serves both paths, and nothing needs the internal CA installed.

## Adding a host

1. Ingress host becomes `x.${EXTERNAL_DOMAIN}`.
2. `cert-manager.io/cluster-issuer: letsencrypt-staging` first. Confirm the
   Certificate goes Ready, then switch to `letsencrypt`. Production rate limits
   are 50 certs and 5 duplicates per week per registered domain; a bad solver
   burns them quickly.
3. To publish it externally as well, add:
   ```yaml
   external-dns.alpha.kubernetes.io/publish-public: "true"
   ```
   Leave it off and the host stays LAN-only — still with a public cert.

Nothing else. The UniFi record and the Cloudflare CNAME are both created
automatically.

## One-time Cloudflare setup, which cannot be done from this repo

cloudflared runs with `--token`, so the tunnel's ingress rules live in the Zero
Trust dashboard rather than in git.

1. **Tunnel origin.** Point the tunnel at the MAIN Traefik, over HTTPS:

   | Field | Value |
   |---|---|
   | Service | `https://traefik.network-system.svc.cluster.local:443` |

   HTTPS rather than HTTP on purpose: every ingress here carries the
   `https-redirectscheme` middleware, so a plain-HTTP origin request gets
   redirected and the tunnel loops. Over HTTPS the redirect never fires. TLS
   verification succeeds without `noTLSVerify` because the origin presents the
   real Let's Encrypt certificate for the requested hostname.

2. **Public hostnames: do NOT use a wildcard.** An earlier draft of this file
   said to add `*` + `${EXTERNAL_DOMAIN}` and delete the DNS record it creates.
   That was wrong for this setup, and unnecessary.

   The tunnel is already configured with explicit per-hostname rules and is
   serving traffic — 211 requests, and rule 0 is:

   ```
   hostname: home-assistant-dad.${EXTERNAL_DOMAIN}
   service:  http://home-assistant-dad.home-automation:8123
   ```

   So it already routes select names, straight to the service, bypassing Traefik.
   Keep that shape: one rule per published name, no wildcard. A wildcard would
   make every name in the zone reachable through the tunnel, which is the
   opposite of what is wanted.

   Note that the existing rules route to SERVICES, not to Traefik. That works,
   but it is why `home-assistant-dad.${EXTERNAL_DOMAIN}` does not resolve or work
   on the LAN: there is no Ingress and no internal record for it. To get one name
   working both ways, its rule has to point at Traefik instead:

   ```
   service: https://traefik.network-system.svc.cluster.local:443
   ```

   Then the single Ingress serves both paths with the same certificate.

## Automating the tunnel rules, so the dashboard stops being the source of truth

The rules above live in the Zero Trust dashboard because cloudflared runs with
`--token` (remotely-managed). They can be moved into this repo, and this is the
piece that makes "select names, automated" actually true:

**The existing token already contains everything a locally-managed tunnel needs.**
A tunnel token is base64 JSON with three fields, verified against the live secret
without printing it:

```
decodes to JSON with keys: ['a', 's', 't']
-> AccountTag=yes  TunnelID=yes (36 chars, a UUID)  TunnelSecret=yes
```

Those are exactly the three fields of a `credentials.json`. So the tunnel can be
converted from remotely- to locally-managed **without recreating it and without
touching the dashboard** — same tunnel, same id, same DNS targets.

What that buys:

* `ingress:` becomes a list in a ConfigMap in git — one entry per published name,
  reviewable in a PR, no wildcard.
* a final catch-all `- service: http_status:404` means an unlisted hostname gets
  a 404 from cloudflared even if a DNS record for it somehow exists. Defence in
  depth that the dashboard flow cannot express.
* `cloudflared tunnel ingress validate` checks the rules offline, so the config
  is verified rather than hoped at.

Two things to carry across when doing it:

* the current rules carry Cloudflare **Access** settings
  (`originRequest.access`, `teamName: borgsnet`, `required: false`). They have to
  be re-expressed in the config file. Worth noting `required: false` means Access
  is not actually enforcing anything today.
* DNS stays external-dns's job either way. Publishing a name then needs the
  annotation (DNS) and the ingress rule (routing) — two places, both in git. A
  short drift check comparing annotated Ingresses against the rule list is worth
  adding so the two cannot silently disagree.

## Why not traefik-external

It was built for this and is no longer needed. It is byte-identical to the main
instance except for replicas (1 vs 2), its ingressClass and `isDefaultClass`, and
it has never served a single request — zero access-log entries. Pointing the
tunnel at the main Traefik means one instance, one cert store, one access log.
Decommissioning it is a separate change; `traefik-external.${BASE_DOMAIN}` still
uses it today.
