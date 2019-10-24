JSONNET_ARGS := -n 2 --max-blank-lines 2 --string-style s --comment-style s
ifneq (,$(shell which jsonnetfmt))
	JSONNET_FMT_CMD := jsonnetfmt
else
	JSONNET_FMT_CMD := jsonnet
	JSONNET_FMT_ARGS := fmt $(JSONNET_ARGS)
endif
JSONNET_FMT := $(JSONNET_FMT_CMD) $(JSONNET_FMT_ARGS)

JB_BINARY := jb
EMBEDMD_BINARY := embedmd
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

**.md: $(shell find examples) build.sh example.jsonnet
	$(EMBEDMD_BINARY) -w `find . -name "*.md" | grep -v vendor`

manifests: examples/kustomize.jsonnet vendor build.sh
	rm -rf manifests
	./build.sh $<

vendor: jsonnetfile.json jsonnetfile.lock.json
	rm -rf vendor
	$(JB_BINARY) install

fmt:
	find . -name 'vendor' -prune -o -name '*.libsonnet' -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNET_FMT) -i

test:
	$(JB_BINARY) install
	./test.sh

test-e2e:
	go test -timeout 55m -v ./tests/e2e -count=1

test-in-docker:
	@echo ">> Compiling assets and generating Kubernetes manifests"
	$(CONTAINER_CMD) make $(MFLAGS) test

.PHONY: generate generate-in-docker test test-in-docker fmt
