.PHONY: view deploy

view:
	kustomize build .

deploy:
	kustomize build . | kubectl apply -f -