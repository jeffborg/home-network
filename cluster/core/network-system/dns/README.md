# external dns setup for internal lan via UniFi webhook

# see https://github.com/kashalls/external-dns-unifi-webhook

External-DNS uses the UniFi webhook provider (`kashalls/external-dns-unifi-webhook`) running
as a sidecar container to manage DNS records directly in the UniFi controller.

## Prerequisites

Create a Kubernetes secret with your UniFi admin credentials in the `network-system` namespace:

```sh
kubectl create secret generic external-dns-unifi-credentials \
  --namespace network-system \
  --from-literal=username=<unifi-admin-user> \
  --from-literal=password=<unifi-admin-password>
```

## Configuration

- `UNIFI_HOST`: Internal URL of the UniFi controller (default: `https://unifi.network.svc.cluster.local:8443`)
- `UNIFI_SKIP_TLS_VERIFY`: Set to `"true"` when using a self-signed or internal CA certificate
