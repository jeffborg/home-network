init:
	docker run --rm -i -t -v ${PWD}:/data -w /data hashicorp/terraform:1.0.5 init
plan:
	docker run --rm -i -t -v ${PWD}:/data -w /data hashicorp/terraform:1.0.5 plan
apply:
	docker run --rm -i -t -v ${PWD}:/data -w /data hashicorp/terraform:1.0.5 apply
destroy:
	docker run --rm -i -t -v ${PWD}:/data -w /data hashicorp/terraform:1.0.5 destroy
