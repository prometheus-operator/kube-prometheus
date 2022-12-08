{
  values+:: {
    common+: {
      versions+: {
        pyrra: error 'must provide version',
      } + (import '../versions.json'),
      images+: {
        pyrra+: 'ghcr.io/pyrra-dev/pyrra:v' + $.values.common.versions.pyrra,
      },
    },
    pyrra+: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.pyrra,
      image: $.values.common.images.pyrra,
    },
  },

  local defaults = {
    local defaults = self,

    name:: 'pyrra',
    namespace:: error 'must provide namespace',
    version:: error 'must provide version',
    image: error 'must provide image',
    replicas:: 1,
    port:: 9099,

    commonLabels:: {
      'app.kubernetes.io/name': 'pyrra',
      'app.kubernetes.io/version': defaults.version,
      'app.kubernetes.io/part-of': 'kube-prometheus',
    },
  },

  local pyrra = function(params) {
    local pyrra = self,
    _config:: defaults + params,

    crd: (
      import 'github.com/pyrra-dev/pyrra/config/crd/bases/pyrra.dev_servicelevelobjectives.json'
    ),


    _apiMetadata:: {
      name: pyrra._config.name + '-api',
      namespace: pyrra._config.namespace,
      labels: pyrra._config.commonLabels {
        'app.kubernetes.io/component': 'api',
      },
    },
    apiSelectorLabels:: {
      [labelName]: pyrra._apiMetadata.labels[labelName]
      for labelName in std.objectFields(pyrra._apiMetadata.labels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },

    apiService: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: pyrra._apiMetadata,
      spec: {
        ports: [
          { name: 'http', targetPort: pyrra._config.port, port: pyrra._config.port },
        ],
        selector: pyrra.apiSelectorLabels,
      },
    },

    apiDeployment:
      local c = {
        name: pyrra._config.name,
        image: pyrra._config.image,
        args: [
          'api',
          '--api-url=http://%s.%s.svc.cluster.local:9444' % [pyrra.kubernetesService.metadata.name, pyrra.kubernetesService.metadata.namespace],
          '--prometheus-url=http://prometheus-k8s.%s.svc.cluster.local:9090' % pyrra._config.namespace,
        ],
        // resources: pyrra._config.resources,
        ports: [{ containerPort: pyrra._config.port }],
        securityContext: {
          allowPrivilegeEscalation: false,
          readOnlyRootFilesystem: true,
        },
      };

      {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: pyrra._apiMetadata,
        spec: {
          replicas: pyrra._config.replicas,
          selector: {
            matchLabels: pyrra.apiSelectorLabels,
          },
          strategy: {
            rollingUpdate: {
              maxSurge: 1,
              maxUnavailable: 1,
            },
          },
          template: {
            metadata: { labels: pyrra._apiMetadata.labels },
            spec: {
              containers: [c],
              // serviceAccountName: $.serviceAccount.metadata.name,
              nodeSelector: { 'kubernetes.io/os': 'linux' },
            },
          },
        },
      },

    _kubernetesMetadata:: {
      name: pyrra._config.name + '-kubernetes',
      namespace: pyrra._config.namespace,
      labels: pyrra._config.commonLabels {
        'app.kubernetes.io/component': 'kubernetes',
      },
    },
    kubernetesSelectorLabels:: {
      [labelName]: pyrra._kubernetesMetadata.labels[labelName]
      for labelName in std.objectFields(pyrra._kubernetesMetadata.labels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },

    kubernetesServiceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: pyrra._kubernetesMetadata,
    },

    kubernetesClusterRole: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: pyrra._kubernetesMetadata,
      rules: [{
        apiGroups: ['monitoring.coreos.com'],
        resources: ['prometheusrules'],
        verbs: ['create', 'delete', 'get', 'list', 'patch', 'update', 'watch'],
      }, {
        apiGroups: ['monitoring.coreos.com'],
        resources: ['prometheusrules/status'],
        verbs: ['get'],
      }, {
        apiGroups: ['pyrra.dev'],
        resources: ['servicelevelobjectives'],
        verbs: ['create', 'delete', 'get', 'list', 'patch', 'update', 'watch'],
      }, {
        apiGroups: ['pyrra.dev'],
        resources: ['servicelevelobjectives/status'],
        verbs: ['get', 'patch', 'update'],
      }],
    },

    kubernetesClusterRoleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: pyrra._kubernetesMetadata,
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: pyrra.kubernetesClusterRole.metadata.name,
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: pyrra.kubernetesServiceAccount.metadata.name,
        namespace: pyrra._config.namespace,
      }],
    },

    kubernetesService: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: pyrra._kubernetesMetadata,
      spec: {
        ports: [
          { name: 'http', targetPort: 9444, port: 9444 },
        ],
        selector: pyrra.kubernetesSelectorLabels,
      },
    },

    kubernetesDeployment:
      local c = {
        name: pyrra._config.name,
        image: pyrra._config.image,
        args: [
          'kubernetes',
        ],
        // resources: pyrra._config.resources,
        ports: [{ containerPort: pyrra._config.port }],
        securityContext: {
          allowPrivilegeEscalation: false,
          readOnlyRootFilesystem: true,
        },
      };

      {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: pyrra._kubernetesMetadata {
          name: pyrra._config.name + '-kubernetes',
        },
        spec: {
          replicas: pyrra._config.replicas,
          selector: {
            matchLabels: pyrra.kubernetesSelectorLabels,
          },
          strategy: {
            rollingUpdate: {
              maxSurge: 1,
              maxUnavailable: 1,
            },
          },
          template: {
            metadata: { labels: pyrra._kubernetesMetadata.labels },
            spec: {
              containers: [c],
              serviceAccountName: pyrra.kubernetesServiceAccount.metadata.name,
              nodeSelector: { 'kubernetes.io/os': 'linux' },
            },
          },
        },
      },

    // Most of these should eventually be moved to the components themselves.
    // For now, this is a good start to have everything in one place.
    'slo-apiserver-read-response-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'apiserver-read-response-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            errors: {
              metric: 'apiserver_request_total{component="apiserver",verb=~"LIST|GET",code=~"5.."}',
            },
            total: {
              metric: 'apiserver_request_total{component="apiserver",verb=~"LIST|GET"}',
            },
          },
        },
      },
    },

    'slo-apiserver-write-response-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'apiserver-write-response-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            errors: {
              metric: 'apiserver_request_total{component="apiserver",verb=~"POST|PUT|PATCH|DELETE",code=~"5.."}',
            },
            total: {
              metric: 'apiserver_request_total{component="apiserver",verb=~"POST|PUT|PATCH|DELETE"}',
            },
          },
        },
      },
    },

    'slo-apiserver-read-resource-latency': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'apiserver-read-resource-latency',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          latency: {
            success: {
              metric: 'apiserver_request_duration_seconds_bucket{component="apiserver",scope=~"resource|",verb=~"LIST|GET",le="0.1"}',
            },
            total: {
              metric: 'apiserver_request_duration_seconds_count{component="apiserver",scope=~"resource|",verb=~"LIST|GET"}',
            },
          },
        },
      },
    },

    'slo-apiserver-read-namespace-latency': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'apiserver-read-namespace-latency',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          latency: {
            success: {
              metric: 'apiserver_request_duration_seconds_bucket{component="apiserver",scope=~"namespace|",verb=~"LIST|GET",le="5"}',
            },
            total: {
              metric: 'apiserver_request_duration_seconds_count{component="apiserver",scope=~"namespace|",verb=~"LIST|GET"}',
            },
          },
        },
      },
    },

    'slo-apiserver-read-cluster-latency': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'apiserver-read-cluster-latency',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          latency: {
            success: {
              metric: 'apiserver_request_duration_seconds_bucket{component="apiserver",scope=~"cluster|",verb=~"LIST|GET",le="5"}',
            },
            total: {
              metric: 'apiserver_request_duration_seconds_count{component="apiserver",scope=~"cluster|",verb=~"LIST|GET"}',
            },
          },
        },
      },
    },

    'slo-kubelet-request-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'kubelet-request-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            errors: {
              metric: 'rest_client_requests_total{job="kubelet",code=~"5.."}',
            },
            total: {
              metric: 'rest_client_requests_total{job="kubelet"}',
            },
          },
        },
      },
    },

    'slo-kubelet-runtime-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'kubelet-runtime-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            errors: {
              metric: 'kubelet_runtime_operations_errors_total{job="kubelet"}',
            },
            total: {
              metric: 'kubelet_runtime_operations_total{job="kubelet"}',
            },
          },
        },
      },
    },

    'slo-coredns-response-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'coredns-response-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99.99',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            errors: {
              metric: 'coredns_dns_responses_total{job="kube-dns",rcode="SERVFAIL"}',
            },
            total: {
              metric: 'coredns_dns_responses_total{job="kube-dns"}',
            },
          },
        },
      },
    },

    'slo-prometheus-operator-reconcile-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'prometheus-operator-reconcile-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '95',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            errors: {
              metric: 'prometheus_operator_reconcile_errors_total{job="prometheus-operator"}',
            },
            total: {
              metric: 'prometheus_operator_reconcile_operations_total{job="prometheus-operator"}',
            },
            grouping: ['controller'],
          },
        },
      },
    },

    'slo-prometheus-operator-http-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'prometheus-operator-http-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99.5',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            errors: {
              metric: 'prometheus_operator_kubernetes_client_http_requests_total{job="prometheus-operator",status_code=~"5.."}',
            },
            total: {
              metric: 'prometheus_operator_kubernetes_client_http_requests_total{job="prometheus-operator"}',
            },
          },
        },
      },
    },

    'slo-prometheus-rule-evaluation-failures': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'prometheus-rule-evaluation-failures',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99.99',
        window: '2w',
        description: 'Rule and alerting rules are being evaluated every few seconds. This needs to work for recording rules to be created and most importantly for alerts to be evaluated.',
        indicator: {
          ratio: {
            errors: {
              metric: 'prometheus_rule_evaluation_failures_total{job="prometheus-k8s"}',
            },
            total: {
              metric: 'prometheus_rule_evaluations_total{job="prometheus-k8s"}',
            },
          },
        },
      },
    },

    'slo-prometheus-sd-kubernetes-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'prometheus-sd-kubernetes-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: 'If there are too many errors Prometheus is having a bad time discovering new Kubernetes services.',
        indicator: {
          ratio: {
            errors: {
              metric: 'prometheus_sd_kubernetes_http_request_total{job="prometheus-k8s",status_code=~"5..|<error>"}',
            },
            total: {
              metric: 'prometheus_sd_kubernetes_http_request_total{job="prometheus-k8s"}',
            },
          },
        },
      },
    },

    'slo-prometheus-query-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'prometheus-query-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            grouping: ['handler'],
            errors: {
              metric: 'prometheus_http_requests_total{job="prometheus-k8s",handler=~"/api/v1/query.*",code=~"5.."}',
            },
            total: {
              metric: 'prometheus_http_requests_total{job="prometheus-k8s",handler=~"/api/v1/query.*"}',
            },
          },
        },
      },
    },

    'slo-prometheus-notification-errors': {
      apiVersion: 'pyrra.dev/v1alpha1',
      kind: 'ServiceLevelObjective',
      metadata: {
        name: 'prometheus-notification-errors',
        namespace: pyrra._config.namespace,
        labels: {
          prometheus: 'k8s',
          role: 'alert-rules',
        },
      },
      spec: {
        target: '99',
        window: '2w',
        description: '',
        indicator: {
          ratio: {
            errors: {
              metric: 'prometheus_notifications_errors_total{job="prometheus-k8s"}',
            },
            total: {
              metric: 'prometheus_notifications_sent_total{job="prometheus-k8s"}',
            },
          },
        },
      },
    },
  },

  pyrra: pyrra($.values.pyrra),
}
