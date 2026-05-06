# external dns setup for internal lan via UniFi webhook

# see https://github.com/kashalls/external-dns-unifi-webhook

External-DNS uses the UniFi webhook provider (`kashalls/external-dns-unifi-webhook`) running
as a sidecar container to manage DNS records directly in the UniFi controller.

## Prerequisites

Create a Kubernetes secret with your UniFi API key in the `network-system` namespace:

```sh
kubectl create secret generic external-dns-unifi-secret \
  --namespace network-system \
  --from-literal=api-key=<your-unifi-api-key>
```

See the [provider README](https://github.com/kashalls/external-dns-unifi-webhook/blob/main/README.md)
for instructions on creating the API key in your UniFi controller.

## Configuration

- `UNIFI_HOST`: IP/hostname of the UniFi controller (default: `https://192.168.100.1`)
- `UNIFI_EXTERNAL_CONTROLLER`: Set to `"false"` for a self-hosted (non-cloud) controller
- `UNIFI_API_KEY`: API key sourced from `external-dns-unifi-secret`
