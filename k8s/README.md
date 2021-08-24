kubernetes cluster on raspberri pi? or vms?? or both?

install rasbian onto sd card - enabled ssh via touch boot/ssh file
setup ssh keys onto your new pi

edit pi-hosts.txt to include your ip

using ansible
```bash
> cd k8s/ansible
> ansible-galaxy install -r requirements.yml
> ansible-playbook rpi.yaml
```

