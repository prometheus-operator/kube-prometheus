## Example of conversion of a legacy my.jsonnet file

An example conversion of a legacy custom jsonnet file to release-0.8
format can be seen by viewing and comparing this
[release-0.3 jsonnet file](my.release-0.3.jsonnet) (when the github
repo was under `https://github.com/coreos/kube-prometheus...`)
and the corresponding [release-0.8 jsonnet file](my.release-0.8.jsonnet).

These two files have had necessary blank lines added so that they
can be compared side-by-side and line-by-line on screen.

The conversion covers both the change of stopping using ksonnet after
release-0.3 and also the major migration after release-0.7 as described in
[migration-guide.md](../migration-guide.md)

The sample files are intended as an example of format conversion and
not necessarily best practice for the files in release-0.3 or release-0.8.

Below are three sample extracts of the conversion as an indication of the
changes required.

<table>
<tr>
<th> release-0.3 </th>
<th> release-0.8 </th>
</tr>
<tr>
<td>

```jsonnet
local kp =
  (import 'kube-prometheus/kube-prometheus.libsonnet') +
  (import 'kube-prometheus/kube-prometheus-kubeadm.libsonnet') +
  (import 'kube-prometheus/kube-prometheus-static-etcd.libsonnet') +

  {
    _config+:: {
      // Override namespace
      namespace: 'monitoring',
  
  
  
  
   
   
   
```

</td>
<td>

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') +
  // kubeadm now achieved by setting platform value - see 9 lines below
  (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  (import 'kube-prometheus/addons/podsecuritypolicies.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },

      // Add kubeadm platform-specific items,
      // including kube-contoller-manager and kube-scheduler discovery
      kubePrometheus+: {
        platform: 'kubeadm',
      },
```

</td>
</tr>
</table>
<table>
<tr>
<th> release-0.3 </th>
<th> release-0.8 </th>
</tr>
<tr>
<td>

```jsonnet
    // Add additional ingresses
    // See https://github.com/coreos/kube-prometheus/...
    //           tree/master/examples/ingress.jsonnet
    ingress+:: {
      alertmanager:
        ingress.new() +


        ingress.mixin.metadata.withName('alertmanager') +
        ingress.mixin.metadata.withNamespace($._config.namespace) +
        ingress.mixin.metadata.withAnnotations({
          'kubernetes.io/ingress.class': 'nginx-api',
        }) +

        ingress.mixin.spec.withRules(
          ingressRule.new() +
          ingressRule.withHost(alert_manager_host) +
          ingressRule.mixin.http.withPaths(
            ingressRuleHttpPath.new() +




            ingressRuleHttpPath.mixin.backend
                               .withServiceName('alertmanager-operated') +
            ingressRuleHttpPath.mixin.backend.withServicePort(9093)
          ),
        ) +
        // Note we do not need a TLS secretName here as we are going to use the
        // nginx-ingress default secret which is a wildcard
        // secretName would need to be in the same namespace at this time,
        // see https://github.com/kubernetes/ingress-nginx/issues/2371
        ingress.mixin.spec.withTls(
          ingressTls.new() +
          ingressTls.withHosts(alert_manager_host)
        ),
  
  
```

</td>
<td>

```jsonnet
    // Add additional ingresses
    // See https://github.com/prometheus-operator/kube-prometheus/...
    //           blob/main/examples/ingress.jsonnet
    ingress+:: {
      alertmanager: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: 'alertmanager',
          namespace: $.values.common.namespace,
          annotations: {
            'kubernetes.io/ingress.class': 'nginx-api',
          },
        },
        spec: {
          rules: [{
            host: alert_manager_host,
            http: {
              paths: [{
                path: '/',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: 'alertmanager-operated',
                    port: {
                      number: 9093,
                    },
                  },
                },
              }],
            },
          }],
          tls: [{

            hosts: [alert_manager_host],
          }],
        },
      },
```

</td>
</tr>
</table>
<table>
<tr>
<th> release-0.3 </th>
<th> release-0.8 </th>
</tr>
<tr>
<td>

```jsonnet
    // Additional prometheus rules
    // See https://github.com/coreos/kube-prometheus/docs/...
    //           developing-prometheus-rules-and-grafana-dashboards.md
    //
    // cat my-prometheus-rules.yaml | \
    //   gojsontoyaml -yamltojson | \
    //   jq . > my-prometheus-rules.json
    prometheusRules+:: {














      groups+: import 'my-prometheus-rules.json',


    },
  };
  
  
  
  
```

</td>
<td>

```jsonnet
    // Additional prometheus rules
    // See https://github.com/prometheus-operator/kube-prometheus/blob/main/...
    //           docs/developing-prometheus-rules-and-grafana-dashboards.md...
    //           #pre-rendered-rules
    // cat my-prometheus-rules.yaml | \
    //   gojsontoyaml -yamltojson | \
    //   jq . > my-prometheus-rules.json
    prometheusMe: {
      rules: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          name: 'my-prometheus-rule',
          namespace: $.values.common.namespace,
          labels: {
            'app.kubernetes.io/name': 'kube-prometheus',
            'app.kubernetes.io/part-of': 'kube-prometheus',
            prometheus: 'k8s',
            role: 'alert-rules',
          },
        },
        spec: {
          groups: import 'my-prometheus-rules.json',
        },
      },
    },
  };

...

+ { ['prometheus-my-' + name]: kp.prometheusMe[name] for name in std.objectFields(kp.prometheusMe) }
```

</td>
</tr>
</table>
