module _ // go.mod created for tooling dependencies

go 1.15

require (
	github.com/brancz/gojsontoyaml v0.0.0-20200602132005-3697ded27e8c
	github.com/bwplotka/mdox v0.9.0
	github.com/google/go-jsonnet v0.17.1-0.20210909114553-2f2f6d664f06 // commit on SEP 9th 2021. Needed by jsonnet linter
	github.com/jsonnet-bundler/jsonnet-bundler v0.4.0
	github.com/yannh/kubeconform v0.4.7
	sigs.k8s.io/yaml v1.3.0 // indirect
)
