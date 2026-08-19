SHELL=/bin/bash -o pipefail

BIN_DIR?=$(shell pwd)/tmp/bin

MDOX_BIN=$(BIN_DIR)/mdox
JB_BIN=$(BIN_DIR)/jb
GOJSONTOYAML_BIN=$(BIN_DIR)/gojsontoyaml
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETLINT_BIN=$(BIN_DIR)/jsonnet-lint
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
KUBECONFORM_BIN=$(BIN_DIR)/kubeconform
KUBESCAPE_BIN=~/.kubescape/bin/kubescape
TOOLING=$(JB_BIN) $(GOJSONTOYAML_BIN) $(JSONNET_BIN) $(JSONNETLINT_BIN) $(JSONNETFMT_BIN) $(KUBECONFORM_BIN) $(MDOX_BIN)

JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s

MDOX_VALIDATE_CONFIG?=.mdox.validate.yaml
MD_FILES_TO_FORMAT=$(shell find docs developer-workspace examples experimental jsonnet manifests -name "*.md") $(shell ls *.md)

KUBESCAPE_THRESHOLD=1

##@ General

.PHONY: help
help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} /^[a-zA-Z0-9_.-]+:.*## / {printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: completion
completion: ## Print bash completion script (eval "$(make completion)")
	@printf '%s\n' \
		'_kube_prometheus_make() {' \
		'  local cur opts' \
		'  COMPREPLY=()' \
		'  cur="$${COMP_WORDS[COMP_CWORD]}"' \
		'  if [[ $${COMP_CWORD} -eq 1 ]]; then' \
		'    opts="$$(make -npq 2>/dev/null | awk -F'"'"':'"'"' '"'"'/^[a-zA-Z0-9][^$$#\/\t=]*:([^=]|$$)/ {split($$1,A, /[:]/); for(i in A) if(A[i] ~ /^[a-zA-Z0-9._%][a-zA-Z0-9._%:-]+$$/) print A[i]}'"'"' | sort -u)"' \
		'    COMPREPLY=($$(compgen -W "$${opts}" -- "$${cur}"))' \
		'  fi' \
		'}' \
		'complete -F _kube_prometheus_make make'

.PHONY: completion-zsh
completion-zsh: ## Print zsh completion script (eval "$(make completion-zsh)")
	@printf '%s\n' \
		'#compdef make' \
		'_kube_prometheus_make() {' \
		'  local -a targets' \
		'  targets=("$${(@f)$$(make -npq 2>/dev/null | awk -F'"'"':'"'"' '"'"'/^[a-zA-Z0-9][^$$#\/\t=]*:([^=]|$$)/ {split($$1,A, /[:]/); for(i in A) if(A[i] ~ /^[a-zA-Z0-9._%][a-zA-Z0-9._%:-]+$$/) print A[i]}'"'"' | sort -u)}")' \
		'  _describe '"'"'make targets'"'"' targets' \
		'}' \
		'compdef _kube_prometheus_make make'

all: generate fmt test docs ## Run generate, fmt, test, and docs

.PHONY: clean
clean: ## Remove generated files and directories ignored by git
	# Remove all files and directories ignored by git.
	git clean -Xfd .

##@ Documentation

.PHONY: docs
docs: $(MDOX_BIN) $(shell find examples) build.sh example.jsonnet ## Format markdown and localize/validate links
	@echo ">> formatting and local/remote links"
	$(MDOX_BIN) fmt --soft-wraps -l --links.localize.address-regex="https://prometheus-operator.dev/.*" --links.validate.config-file=$(MDOX_VALIDATE_CONFIG) $(MD_FILES_TO_FORMAT)

.PHONY: check-docs
check-docs: $(MDOX_BIN) $(shell find examples) build.sh example.jsonnet ## Check markdown formatting and links without modifying
	@echo ">> checking formatting and local/remote links"
	$(MDOX_BIN) fmt --soft-wraps --check -l --links.localize.address-regex="https://prometheus-operator.dev/.*" --links.validate.config-file=$(MDOX_VALIDATE_CONFIG) $(MD_FILES_TO_FORMAT)

##@ Code generation

.PHONY: generate
generate: manifests ## Generate Kubernetes manifests from jsonnet

manifests: examples/kustomize.jsonnet $(GOJSONTOYAML_BIN) vendor ## Build manifests from examples/kustomize.jsonnet
	./build.sh $<

manifests-metrics-server: examples/metrics-server.jsonnet $(GOJSONTOYAML_BIN) vendor ## Build manifests from examples/metrics-server.jsonnet
	./build.sh $<

manifests-perses: examples/perses.jsonnet $(GOJSONTOYAML_BIN) vendor ## Build manifests from examples/perses.jsonnet
	./build.sh $<

vendor: $(JB_BIN) jsonnetfile.json jsonnetfile.lock.json ## Install jsonnet dependencies
	rm -rf vendor
	$(JB_BIN) install

crdschemas: vendor ## Generate CRD JSON schemas for kubeconform
	./scripts/generate-schemas.sh

.PHONY: update
update: $(JB_BIN) ## Update jsonnet dependencies
	$(JB_BIN) update

##@ Validation

.PHONY: validate
validate: validate-1.35 validate-1.36 validate-1.37 ## Validate manifests against supported Kubernetes versions

validate-1.35: ## Validate manifests against Kubernetes 1.35
	KUBE_VERSION=1.35.8 $(MAKE) kubeconform

validate-1.36: ## Validate manifests against Kubernetes 1.36
	KUBE_VERSION=1.36.4 $(MAKE) kubeconform

validate-1.37: ## Validate manifests against Kubernetes 1.37
	KUBE_VERSION=1.37.0 $(MAKE) kubeconform

.PHONY: kubeconform
kubeconform: crdschemas manifests $(KUBECONFORM_BIN) ## Validate manifests against KUBE_VERSION using kubeconform
	$(KUBECONFORM_BIN) -kubernetes-version $(KUBE_VERSION) -schema-location 'default' -schema-location 'crdschemas/{{ .ResourceKind }}.json' -skip CustomResourceDefinition manifests/

.PHONY: kubescape
kubescape: $(KUBESCAPE_BIN) ## Runs a security analysis on generated manifests - failing if risk score is above threshold percentage 't'
	$(KUBESCAPE_BIN) scan framework nsa --compliance-threshold $(KUBESCAPE_THRESHOLD) -v --exceptions 'kubescape-exceptions.json' manifests/

$(KUBESCAPE_BIN):
	curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash

##@ Code quality

.PHONY: fmt
fmt: $(JSONNETFMT_BIN) ## Format jsonnet files
	find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

.PHONY: lint
lint: $(JSONNETLINT_BIN) vendor ## Lint jsonnet files
	find jsonnet/ -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETLINT_BIN) -J vendor

##@ Testing

.PHONY: test
test: $(JB_BIN) ## Run jsonnet unit tests
	$(JB_BIN) install
	./scripts/test.sh

.PHONY: test-e2e
test-e2e: ## Run end-to-end tests
	go test -timeout 55m -v ./tests/e2e -count=1

.PHONY: test-e2e-metrics-server
test-e2e-metrics-server: ## Run metrics-server end-to-end tests
	RESOURCE_METRICS_API=metrics-server go test -mod=mod -timeout 55m -v ./tests/e2e -count=1 -run TestMetricsServerDeployment

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from scripts/tools.go
	@cd scripts && cat tools.go | grep _ | awk -F'"' '{print $$2}' | xargs -tI % go build -modfile=go.mod -o $(BIN_DIR) %

##@ Deployment

.PHONY: deploy
deploy: ## Deploy kube-prometheus to a local Kind cluster
	./developer-workspace/codespaces/prepare-kind.sh
	./developer-workspace/common/deploy-kube-prometheus.sh
