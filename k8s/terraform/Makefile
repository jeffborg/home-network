init:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -w /data/k8s/terraform hashicorp/terraform:1.0.11 init
plan:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -w /data/k8s/terraform hashicorp/terraform:1.0.11 plan
apply:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -w /data/k8s/terraform hashicorp/terraform:1.0.11 apply
destroy:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -w /data/k8s/terraform hashicorp/terraform:1.0.11 destroy
console:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -w /data/k8s/terraform hashicorp/terraform:1.0.11 console
shell:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -w /data/k8s/terraform --entrypoint sh hashicorp/terraform:1.0.11 