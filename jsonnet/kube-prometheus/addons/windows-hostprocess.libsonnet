local windowsdashboards = import 'github.com/kubernetes-monitoring/kubernetes-mixin/dashboards/windows.libsonnet';
local windowsrules = import 'github.com/kubernetes-monitoring/kubernetes-mixin/rules/windows.libsonnet';

local defaults = {
  local defaults = self,
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  name:: 'windows-exporter',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide version',
  resources:: {
    requests: { cpu: '300m', memory: '200Mi' },
    limits: { memory: '200Mi' },
  },
  collectorsEnabled:: 'cpu,logical_disk,net,os,system,container,memory',
  scrapeTimeout:: '15s',
  interval:: '30s',
  listenAddress:: '127.0.0.1',
  port:: 9182,
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'windows-exporter',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

local windowsExporter = function(params) {
  local we = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(we._config.resources),
  _metadata:: {
    name: we._config.name,
    namespace: we._config.namespace,
    labels: we._config.commonLabels,
  },

  daemonset: {
    apiVersion: 'apps/v1',
    kind: 'DaemonSet',
    metadata: we._metadata,
    spec: {
      selector: {
        matchLabels: we._config.selectorLabels,
      },
      updateStrategy: {
        type: 'RollingUpdate',
        rollingUpdate: { maxUnavailable: '10%' },
      },
      template: {
        metadata: we._metadata,
        spec: {
          securityContext: {
            windowsOptions: {
              hostProcess: true,
              runAsUserName: 'NT AUTHORITY\\system',
            },
          },
          hostNetwork: true,
          initContainers: [
            {
              name: 'configure-firewall',
              image: 'mcr.microsoft.com/windows/nanoserver:1809',
              resources: we._config.resources,
              command: [
                'powershell',
              ],
              args: [
                'New-NetFirewallRule',
                '-DisplayName',
                "'windows-exporter'",
                '-Direction',
                'inbound',
                '-Profile',
                'Any',
                '-Action',
                'Allow',
                '-LocalPort',
                std.toString(we._config.port),
                '-Protocol',
                'TCP',
              ],
            },
          ],
          containers: [
            {
              args: [
                '--config.file=%CONTAINER_SANDBOX_MOUNT_POINT%/config.yml',
                '--collector.textfile.directory=%CONTAINER_SANDBOX_MOUNT_POINT%',
              ],
              name: we._config.name,
              image: we._config.image + ':' + we._config.version,
              imagePullPolicy: 'Always',
              resources: we._config.resources,
              ports: [
                {
                  containerPort: we._config.port,
                  hostPort: we._config.port,
                  name: 'http',
                },
              ],
              volumeMounts: [
                {
                  name: 'windows-exporter-config',
                  mountPath: '/config.yml',
                  subPath: 'config.yml',
                },
              ],
            },
          ],
          nodeSelector: {
            'kubernetes.io/os': 'windows',
          },
          volumes: [
            {
              name: 'windows-exporter-config',
              configMap: {
                name: we._config.name,
              },
            },
          ],
        },
      },
    },
  },
  configmap: {
    kind: 'ConfigMap',
    apiVersion: 'v1',
    metadata: we._metadata,
    data: {
      'config.yml': "collectors:\n  enabled: '" + we._config.collectorsEnabled + "'",
    },
  },
  podmonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PodMonitor',
    metadata: we._metadata,
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      selector: {
        matchLabels: we._config.selectorLabels,
      },
      podMetricsEndpoints: [
        {
          port: 'http',
          scheme: 'http',
          scrapeTimeout: we._config.scrapeTimeout,
          interval: we._config.interval,
          relabelings: [
            {
              action: 'replace',
              regex: '(.*)',
              replacement: '$1',
              sourceLabels: ['__meta_kubernetes_pod_node_name'],
              targetLabel: 'instance',
            },
          ],
        },
      ],
    },
  },
};

{
  values+:: {
    windowsExporter+: {
      name: defaults.name,
      namespace: $.values.common.namespace,
    },
    grafana+:: {
      dashboards+:: windowsdashboards {
        _config: $.kubernetesControlPlane.mixin._config {
          windowsExporterSelector: 'job="' + $.values.windowsExporter.name + '"',
        },
      }.grafanaDashboards,
    },
  },
  kubernetesControlPlane+: {
    mixin+:: {
      prometheusRules+:: {
        groups+: windowsrules {
          _config: $.kubernetesControlPlane.mixin._config {
            windowsExporterSelector: 'job="' + $.values.windowsExporter.name + '"',
          },
        }.prometheusRules.groups,
      },
    },
  },
  windowsExporter: windowsExporter($.values.windowsExporter),
}
