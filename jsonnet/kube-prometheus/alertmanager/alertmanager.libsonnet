{
  _config+:: {
    namespace: 'default',

    versions+:: {
      alertmanager: 'v0.21.0',
    },

    imageRepos+:: {
      alertmanager: 'quay.io/prometheus/alertmanager',
    },

    alertmanager+:: {
      name: 'main',
      config: {
        global: {
          resolve_timeout: '5m',
        },
        inhibit_rules: [{
          source_match: {
            severity: 'critical',
          },
          target_match_re: {
            severity: 'warning|info',
          },
          equal: ['namespace', 'alertname'],
        }, {
          source_match: {
            severity: 'warning',
          },
          target_match_re: {
            severity: 'info',
          },
          equal: ['namespace', 'alertname'],
        }],
        route: {
          group_by: ['namespace'],
          group_wait: '30s',
          group_interval: '5m',
          repeat_interval: '12h',
          receiver: 'Default',
          routes: [
            { receiver: 'Watchdog', match: { alertname: 'Watchdog' } },
            { receiver: 'Critical', match: { severity: 'critical' } },
          ],
        },
        receivers: [
          { name: 'Default' },
          { name: 'Watchdog' },
          { name: 'Critical' },
        ],
      },
      replicas: 3,
      labels: {
        'app.kubernetes.io/name': 'alertmanager',
        'app.kubernetes.io/version': $._config.versions.alertmanager,
        'app.kubernetes.io/component': 'alert-router',
        'app.kubernetes.io/part-of': 'kube-prometheus',
      },
      selectorLabels: {
        [labelName]: $._config.alertmanager.labels[labelName]
        for labelName in std.objectFields($._config.alertmanager.labels)
        if !std.setMember(labelName, ['app.kubernetes.io/version'])
      },
    },
  },

  alertmanager+:: {
    secret: {
      apiVersion: 'v1',
      kind: 'Secret',
      type: 'Opaque',
      metadata: {
        name: 'alertmanager-' + $._config.alertmanager.name,
        namespace: $._config.namespace,
        labels: { alertmanager: $._config.alertmanager.name } + $._config.alertmanager.labels,
      },
      stringData: {
        'alertmanager.yaml': if std.type($._config.alertmanager.config) == 'object'
        then
          std.manifestYamlDoc($._config.alertmanager.config)
        else
          $._config.alertmanager.config,
      },
    },

    serviceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: 'alertmanager-' + $._config.alertmanager.name,
        namespace: $._config.namespace,
        labels: { alertmanager: $._config.alertmanager.name } + $._config.alertmanager.labels,
      },
    },

    service: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'alertmanager-' + $._config.alertmanager.name,
        namespace: $._config.namespace,
        labels: { alertmanager: $._config.alertmanager.name } + $._config.alertmanager.labels,
      },
      spec: {
        ports: [
          { name: 'web', targetPort: 'web', port: 9093 },
        ],
        selector: {
          app: 'alertmanager',
          alertmanager: $._config.alertmanager.name,
        } + $._config.alertmanager.selectorLabels,
        sessionAffinity: 'ClientIP',
      },
    },

    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'alertmanager',
        namespace: $._config.namespace,
        labels: $._config.alertmanager.labels,
      },
      spec: {
        selector: {
          matchLabels: {
            alertmanager: $._config.alertmanager.name,
          } + $._config.alertmanager.selectorLabels,
        },
        endpoints: [
          { port: 'web', interval: '30s' },
        ],
      },
    },

    alertmanager: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'Alertmanager',
      metadata: {
        name: $._config.alertmanager.name,
        namespace: $._config.namespace,
        labels: {
          alertmanager: $._config.alertmanager.name,
        } + $._config.alertmanager.labels,
      },
      spec: {
        replicas: $._config.alertmanager.replicas,
        version: $._config.versions.alertmanager,
        image: $._config.imageRepos.alertmanager + ':' + $._config.versions.alertmanager,
        podMetadata: {
          labels: $._config.alertmanager.labels,
        },
        nodeSelector: { 'kubernetes.io/os': 'linux' },
        serviceAccountName: 'alertmanager-' + $._config.alertmanager.name,
        securityContext: {
          runAsUser: 1000,
          runAsNonRoot: true,
          fsGroup: 2000,
        },
      },
    },
  },
}
