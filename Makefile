SHELL=/bin/bash -o pipefail

export GO111MODULE=on

BIN_DIR?=$(shell pwd)/tmp/bin

EMBEDMD_BIN=$(BIN_DIR)/embedmd
JB_BIN=$(BIN_DIR)/jb
GOJSONTOYAML_BIN=$(BIN_DIR)/gojsontoyaml
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
TOOLING=$(EMBEDMD_BIN) $(JB_BIN) $(GOJSONTOYAML_BIN) $(JSONNET_BIN) $(JSONNETFMT_BIN)

JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s

all: generate fmt test

.PHONY: clean
clean:
	# Remove all files and directories ignored by git.
	git clean -Xfd .

.PHONY: generate
generate: manifests **.md

**.md: $(EMBEDMD_BIN) $(shell find examples) build.sh example.jsonnet
	$(EMBEDMD_BIN) -w `find . -name "*.md" | grep -v vendor`

manifests: examples/kustomize.jsonnet $(GOJSONTOYAML_BIN) vendor build.sh
	./build.sh $<

vendor: $(JB_BIN) jsonnetfile.json jsonnetfile.lock.json
	rm -rf vendor
	$(JB_BIN) install

.PHONY: fmt
fmt: $(JSONNETFMT_BIN)
	find . -name 'vendor' -prune -o -name '*.libsonnet' -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

.PHONY: test
test: $(JB_BIN)
	$(JB_BIN) install
	./test.sh

.PHONY: test-e2e
test-e2e:
	go test -timeout 55m -v ./tests/e2e -count=1

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from scripts/tools.go
	@cat scripts/tools.go | grep _ | awk -F'"' '{print $$2}' | GOBIN=$(BIN_DIR) xargs -tI % go install %
