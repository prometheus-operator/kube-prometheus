## Security

The manifests generated in this repository are subject to a security audit in CI via [kubescape](https://github.com/armosec/kubescape).
The scan can be run locally via `make kubescape`.

While we aim for best practices in terms of security by default, due to the nature of the project, we are required to make the exceptions in the following components:

#### node-exporter
* Host Port is set. [Kubernetes already sets a Host Port by default when Host Network is enabled.](https://github.com/kubernetes/kubernetes/blob/1945829906546caf867992669a0bfa588edf8be6/pkg/apis/core/v1/defaults.go#L402-L411). Since nothing can be done here, we configure it to our preference port.
* Host PID is set to `true`, since node-exporter requires direct access to the host namespace to gather statistics.
* Host Network is set to `true`, since node-exporter requires direct access to the host network to gather statistics.
* `automountServiceAccountToken` is set to `true` on Pod level as kube-rbac-proxy sidecar requires connection to kubernetes API server.

#### prometheus-adapter
* `automountServiceAccountToken` is set to `true` on Pod level as application requires connection to kubernetes API server.

#### blackbox-exporter
* `automountServiceAccountToken` is set to `true` on Pod level as kube-rbac-proxy sidecar requires connection to kubernetes API server.

#### kube-state-metrics
* `automountServiceAccountToken` is set to `true` on Pod level as kube-rbac-proxy sidecars requires connection to kubernetes API server.

#### prometheus-operator
* `automountServiceAccountToken` is set to `true` on Pod level as kube-rbac-proxy sidecars requires connection to kubernetes API server.
