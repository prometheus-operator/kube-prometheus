SHELL=/bin/bash -o pipefail

BIN_DIR?=$(shell pwd)/tmp/bin

MDOX_BIN=$(BIN_DIR)/mdox
JB_BIN=$(BIN_DIR)/jb
GOJSONTOYAML_BIN=$(BIN_DIR)/gojsontoyaml
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETLINT_BIN=$(BIN_DIR)/jsonnet-lint
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
KUBECONFORM_BIN=$(BIN_DIR)/kubeconform
KUBESCAPE_BIN=$(BIN_DIR)/kubescape
TOOLING=$(JB_BIN) $(GOJSONTOYAML_BIN) $(JSONNET_BIN) $(JSONNETLINT_BIN) $(JSONNETFMT_BIN) $(KUBECONFORM_BIN) $(MDOX_BIN) $(KUBESCAPE_BIN)

JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s

MDOX_VALIDATE_CONFIG?=.mdox.validate.yaml
MD_FILES_TO_FORMAT=$(shell find docs developer-workspace examples experimental jsonnet manifests -name "*.md") $(shell ls *.md)

KUBESCAPE_THRESHOLD=1

all: generate fmt test docs

.PHONY: clean
clean:
	# Remove all files and directories ignored by git.
	git clean -Xfd .

.PHONY: docs
docs: $(MDOX_BIN) $(shell find examples) build.sh example.jsonnet
	@echo ">> formatting and local/remote links"
	$(MDOX_BIN) fmt --soft-wraps -l --links.localize.address-regex="https://prometheus-operator.dev/.*" --links.validate.config-file=$(MDOX_VALIDATE_CONFIG) $(MD_FILES_TO_FORMAT)

.PHONY: check-docs
check-docs: $(MDOX_BIN) $(shell find examples) build.sh example.jsonnet
	@echo ">> checking formatting and local/remote links"
	$(MDOX_BIN) fmt --soft-wraps --check -l --links.localize.address-regex="https://prometheus-operator.dev/.*" --links.validate.config-file=$(MDOX_VALIDATE_CONFIG) $(MD_FILES_TO_FORMAT)

.PHONY: generate
generate: manifests

manifests: examples/kustomize.jsonnet $(GOJSONTOYAML_BIN) vendor
	./build.sh $<

vendor: $(JB_BIN) jsonnetfile.json jsonnetfile.lock.json
	rm -rf vendor
	$(JB_BIN) install

crdschemas: vendor
	./scripts/generate-schemas.sh

.PHONY: update
update: $(JB_BIN)
	$(JB_BIN) update

.PHONY: validate
validate: validate-1.27 validate-1.28

validate-1.27:
	KUBE_VERSION=1.27.5 $(MAKE) kubeconform

validate-1.28:
	KUBE_VERSION=1.28.1 $(MAKE) kubeconform

.PHONY: kubeconform
kubeconform: crdschemas manifests $(KUBECONFORM_BIN)
	$(KUBECONFORM_BIN) -kubernetes-version $(KUBE_VERSION) -schema-location 'default' -schema-location 'crdschemas/{{ .ResourceKind }}.json' -skip CustomResourceDefinition manifests/

.PHONY: kubescape
kubescape: $(KUBESCAPE_BIN) ## Runs a security analysis on generated manifests - failing if risk score is above threshold percentage 't'
	$(KUBESCAPE_BIN) scan -s framework -t $(KUBESCAPE_THRESHOLD) nsa manifests/*.yaml --exceptions 'kubescape-exceptions.json'

.PHONY: fmt
fmt: $(JSONNETFMT_BIN)
	find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

.PHONY: lint
lint: $(JSONNETLINT_BIN) vendor
	find jsonnet/ -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETLINT_BIN) -J vendor

.PHONY: test
test: $(JB_BIN)
	$(JB_BIN) install
	./scripts/test.sh

.PHONY: test-e2e
test-e2e:
	go test -timeout 55m -v ./tests/e2e -count=1

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from scripts/tools.go
	@cd scripts && cat tools.go | grep _ | awk -F'"' '{print $$2}' | xargs -tI % go build -modfile=go.mod -o $(BIN_DIR) %

.PHONY: deploy
deploy:
	./developer-workspace/codespaces/prepare-kind.sh
	./developer-workspace/common/deploy-kube-prometheus.sh
