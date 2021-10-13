init:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -v ${HOME}/.terraform.d:/root/.terraform.d -w /data/k8s/stage1-terraform hashicorp/terraform:1.0.5 init
plan:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -v ${HOME}/.terraform.d:/root/.terraform.d -w /data/k8s/stage1-terraform hashicorp/terraform:1.0.5 plan
apply:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -v ${HOME}/.terraform.d:/root/.terraform.d -w /data/k8s/stage1-terraform hashicorp/terraform:1.0.5 apply
destroy:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -v ${HOME}/.terraform.d:/root/.terraform.d -w /data/k8s/stage1-terraform hashicorp/terraform:1.0.5 destroy
console:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -v ${HOME}/.terraform.d:/root/.terraform.d -w /data/k8s/stage1-terraform hashicorp/terraform:1.0.5 console
shell:
	docker run --rm -i -t -v ${PWD}/../..:/data -v ${HOME}/.aws:/root/.aws -v ${HOME}/.terraform.d:/root/.terraform.d -w /data/k8s/stage1-terraform --entrypoint sh hashicorp/terraform:1.0.5 