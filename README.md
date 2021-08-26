# home infrastructure

go into k8s/ansible directory

- apply ansible config

in root folder

- terraform init
- terraform plan
- terraform apply

This will use the k8s conf exported from the ansible step



certificates

ca.crt
===========
put ca cert first
put signed sub ca cert 2nd

ca.key
=============
private key for subca


need to disable certicicates before helm chart is installed
