//+build tools

// Package tools tracks dependencies for tools that used in the build process.
// See https://github.com/golang/go/wiki/Modules
package tools

import (
	_ "github.com/brancz/gojsontoyaml"
	_ "github.com/campoy/embedmd"
	_ "github.com/google/go-jsonnet/cmd/jsonnet"
	_ "github.com/google/go-jsonnet/cmd/jsonnet-lint"
	_ "github.com/google/go-jsonnet/cmd/jsonnetfmt"
	_ "github.com/yannh/kubeconform/cmd/kubeconform"
	_ "github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb"
)
