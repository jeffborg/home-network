# external dns setup for internal lan

# see https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/coredns.md

basically you will end up with `home` `lan` `domain` zones on port 53 on a metallb load balancer ip (hardcoded at the moment)

Configure the edgerouter/dnsmasq instance with

```
options server=/home/192.168.58.251
options server=/lan/192.168.58.251
options server=/domain/192.168.58.251
```
