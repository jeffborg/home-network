Note on the missing NetworkPolicy: flux-web needed
`allow-traefik-to-oauth2-proxy-flux` (#3391) because Flux ships `allow-egress`
into flux-system with `podSelector: {}` and a same-namespace-only ingress rule,
which blocked traefik from reaching the proxy.

database-system is a new namespace with no NetworkPolicies, and neither the CNPG
operator chart nor the barman plugin adds any, so no equivalent is needed here.
Checked rather than assumed -- it is the third thing of this shape to bite
(#3368, #3386, #3391), so it is worth checking again if either chart starts
shipping policies.
