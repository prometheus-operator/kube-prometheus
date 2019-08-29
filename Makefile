JSONNET_FMT := jsonnet fmt -n 2 --max-blank-lines 2 --string-style s --comment-style s

JB_BINARY:=$(GOPATH)/bin/jb
EMBEDMD_BINARY:=$(GOPATH)/bin/embedmd
CONTAINER_CMD:=docker run --rm \
		-e http_proxy -e https_proxy -e no_proxy \
		-u="$(shell id -u):$(shell id -g)" \
		-v "$(shell go env GOCACHE):/.cache/go-build" \
		-v "$(PWD):/go/src/github.com/coreos/kube-prometheus:Z" \
		-w "/go/src/github.com/coreos/kube-prometheus" \
		quay.io/coreos/jsonnet-ci

all: generate fmt test

.PHONY: generate-in-docker
generate-in-docker:
	@echo ">> Compiling assets and generating Kubernetes manifests"
	$(CONTAINER_CMD) make $(MFLAGS) generate

.PHONY: clean
clean:
	# Remove all files and directories ignored by git.
	git clean -Xfd .

generate: manifests **.md

**.md: $(EMBEDMD_BINARY) $(shell find examples) build.sh example.jsonnet
	$(EMBEDMD_BINARY) -w `find . -name "*.md" | grep -v vendor`

manifests: vendor example.jsonnet build.sh
	rm -rf manifests
	./build.sh ./examples/kustomize.jsonnet

vendor: $(JB_BINARY) jsonnetfile.json jsonnetfile.lock.json
	rm -rf vendor
	$(JB_BINARY) install

fmt:
	find . -name 'vendor' -prune -o -name '*.libsonnet' -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNET_FMT) -i

test: $(JB_BINARY)
	$(JB_BINARY) install
	./test.sh

test-e2e:
	go test -timeout 55m -v ./tests/e2e -count=1

test-in-docker:
	@echo ">> Compiling assets and generating Kubernetes manifests"
	$(CONTAINER_CMD) make $(MFLAGS) test

$(JB_BINARY):
	go get -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb

$(EMBEDMD_BINARY):
	go get github.com/campoy/embedmd

.PHONY: generate generate-in-docker test test-in-docker fmt
