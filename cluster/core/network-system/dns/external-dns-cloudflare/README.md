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

2. **Public hostname.** Add a wildcard entry (`*` + `${EXTERNAL_DOMAIN}`) so the
   tunnel will accept any hostname and forward it. Then **delete the wildcard DNS
   record Cloudflare creates with it** — otherwise every name in the zone
   resolves to the tunnel and "opt-in" means nothing. The tunnel rule is what you
   want to keep; the DNS records are external-dns's job.

   Routing stays safe either way: Traefik matches on Host, and internal-only
   hosts are `*.${BASE_DOMAIN}`, so a `${EXTERNAL_DOMAIN}` request cannot reach
   them.

## Why not traefik-external

It was built for this and is no longer needed. It is byte-identical to the main
instance except for replicas (1 vs 2), its ingressClass and `isDefaultClass`, and
it has never served a single request — zero access-log entries. Pointing the
tunnel at the main Traefik means one instance, one cert store, one access log.
Decommissioning it is a separate change; `traefik-external.${BASE_DOMAIN}` still
uses it today.
