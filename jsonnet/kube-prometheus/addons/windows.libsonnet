local windowsdashboards = import 'github.com/kubernetes-monitoring/kubernetes-mixin/dashboards/windows.libsonnet';
local windowsrules = import 'github.com/kubernetes-monitoring/kubernetes-mixin/rules/windows.libsonnet';

{
  values+:: {
    // This needs to follow prometheus naming convention and not prometheus-operator one
    windowsScrapeConfig+:: {
      job_name: 'windows-exporter',
      static_configs: [
        {
          targets: [error 'must provide targets array'],
        },
      ],
      relabel_configs: [
        {
          action: 'replace',
          regex: '(.*)',
          replacement: '$1',
          source_labels: [
            '__meta_kubernetes_endpoint_address_target_name',
          ],
          target_label: 'instance',
        },
      ],
    },

    grafana+:: {
      dashboards+:: windowsdashboards {
        _config: $.kubernetesControlPlane.mixin._config {
          wmiExporterSelector: 'job="' + $.values.windowsScrapeConfig.job_name + '"',
        },
      }.grafanaDashboards,
    },
  },
  kubernetesControlPlane+: {
    mixin+:: {
      prometheusRules+:: {
        groups+: windowsrules {
          _config: $.kubernetesControlPlane.mixin._config {
            wmiExporterSelector: 'job="' + $.values.windowsScrapeConfig.job_name + '"',
          },
        }.prometheusRules.groups,
      },
    },
  },
  prometheus+: {
    local p = self,
    local sc = [$.values.windowsScrapeConfig],
    prometheus+: {
      spec+: {
        additionalScrapeConfigs: {
          name: 'prometheus-' + p._config.name + '-additional-scrape-config',
          key: 'prometheus-additional.yaml',
        },
      },

    },
    windowsConfig: {
      apiVersion: 'v1',
      kind: 'Secret',
      metadata: {
        name: 'prometheus-' + p._config.name + '-additional-scrape-config',
        namespace: p._config.namespace,
      },
      stringData: {
        'prometheus-additional.yaml': std.manifestYamlDoc(sc),
      },
    },
  },
}
