# kubernetes dashboard

https://rancher.com/docs/k3s/latest/en/installation/kube-dashboard/

kubectl proxy
kubectl -n kubernetes-dashboard describe secret admin-user-token | grep '^token'

http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
