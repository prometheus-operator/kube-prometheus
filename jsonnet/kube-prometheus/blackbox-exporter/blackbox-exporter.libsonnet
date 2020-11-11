{
  _config+:: {
    namespace: 'default',

    versions+:: {
      blackboxExporter: 'v0.18.0',
      configmapReloader: 'v0.4.0'
    },

    imageRepos+:: {
      blackboxExporter: 'quay.io/prometheus/blackbox-exporter',
      configmapReloader: 'jimmidyson/configmap-reload'
    },

    resources+:: {
      'blackbox-exporter': {
        requests: { cpu: '10m', memory: '20Mi' },
        limits: { cpu: '20m', memory: '40Mi' },
      }
    },

    blackboxExporter: {
      port: 9115,
      replicas: 1,
      matchLabels: {
        'app.kubernetes.io/name': 'blackbox-exporter',
      },
      assignLabels: self.matchLabels + {
        'app.kubernetes.io/version': $._config.versions.blackboxExporter
      },
      modules: {
        http_2xx: {
          prober: 'http'
        },
        http_post_2xx: {
          prober: 'http',
          http: {
            method: 'POST'
          }
        },
        tcp_connect: {
          prober: 'tcp'
        },
        pop3s_banner: {
          prober: 'tcp',
          tcp: {
            query_response: [
              { expect: '^+OK' }
            ],
            tls: true,
            tls_config: {
              insecure_skip_verify: false
            }
          }
        },
        ssh_banner: {
          prober: 'tcp',
          tcp: {
            query_response: [
              { expect: '^SSH-2.0-' }
            ]
          }
        },
        irc_banner: {
          prober: 'tcp',
          tcp: {
            query_response: [
              { send: 'NICK prober' },
              { send: 'USER prober prober prober :prober' },
              { expect: 'PING :([^ ]+)', send: 'PONG ${1}' },
              { expect: '^:[^ ]+ 001' }
            ]
          }
        },
      },
      privileged:
        local icmpModules = [self.modules[m] for m in std.objectFields(self.modules) if self.modules[m].prober == 'icmp'];
        std.length(icmpModules) > 0
    }
  },

  blackboxExporter+::
    local bb = $._config.blackboxExporter;
    {
      configuration: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: 'blackbox-exporter-configuration',
          namespace: $._config.namespace
        },
        data: {
          'config.yml': std.manifestYamlDoc({ modules: bb.modules })
        }
      },

      serviceAccount: {
        apiVersion: 'v1',
        kind: 'ServiceAccount',
        metadata: {
          name: 'blackbox-exporter',
          namespace: $._config.namespace,
        },
      },

      deployment: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: 'blackbox-exporter',
          namespace: $._config.namespace,
          labels: bb.assignLabels,
        },
        spec: {
          replicas: bb.replicas,
          selector: { matchLabels: bb.matchLabels },
          template: {
            metadata: { labels: bb.assignLabels },
            spec: {
              containers: [
                {
                  name: 'blackbox-exporter',
                  image: $._config.imageRepos.blackboxExporter + ':' + $._config.versions.blackboxExporter,
                  ports: [{
                    name: 'http',
                    containerPort: bb.port,
                  }],
                  resources: {
                    requests: $._config.resources['blackbox-exporter'].requests,
                    limits: $._config.resources['blackbox-exporter'].limits
                  },
                  securityContext: if bb.privileged then {
                                     runAsNonRoot: false,
                                     capabilities: { drop: [ 'ALL' ], add: [ 'NET_RAW'] }
                                   } else {
                                     runAsNonRoot: true,
                                     runAsUser: 65534
                                   },
                  volumeMounts: [{
                    mountPath: '/etc/blackbox_exporter/',
                    name: 'config',
                    readOnly: true
                  }]
                },
                {
                  name: 'module-configmap-reloader',
                  image: $._config.imageRepos.configmapReloader + ':' + $._config.versions.configmapReloader,
                  args: [
                    '--webhook-url=http://localhost:' + bb.port + '/-/reload',
                    '--volume-dir=/etc/blackbox_exporter/'
                  ],
                  resources: {
                    requests: $._config.resources['blackbox-exporter'].requests,
                    limits: $._config.resources['blackbox-exporter'].limits
                  },
                  securityContext: { runAsNonRoot: true, runAsUser: 65534 },
                  terminationMessagePath: '/dev/termination-log',
                  terminationMessagePolicy: 'FallbackToLogsOnError',
                  volumeMounts: [{
                    mountPath: '/etc/blackbox_exporter/',
                    name: 'config',
                    readOnly: true
                  }]
                }
              ],
              nodeSelector: { 'kubernetes.io/os': 'linux' },
              serviceAccountName: 'blackbox-exporter',
              volumes: [{
                name: 'config',
                configMap: { name: 'blackbox-exporter-configuration' }
              }]
            }
          }
        }
      },

      service: {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: 'blackbox-exporter',
          namespace: $._config.namespace,
          labels: bb.assignLabels,
        },
        spec: {
          ports: [{ name: 'http', port: bb.port, targetPort: 'http' }],
          selector: bb.matchLabels,
        }
      },

      serviceMonitor:
        {
          apiVersion: 'monitoring.coreos.com/v1',
          kind: 'ServiceMonitor',
          metadata: {
            name: 'blackbox-exporter',
            labels: bb.assignLabels
          },
          spec: {
            endpoints: [ {
              interval: '30s',
              path: '/metrics',
              port: 'http'
            } ],
            selector: {
              matchLabels: bb.matchLabels
            }
          }
        }
    }
}
