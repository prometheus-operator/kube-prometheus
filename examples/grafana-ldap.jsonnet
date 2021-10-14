local kp =
  (import 'kube-prometheus/main.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
      grafana+: {
        config+: {
          sections: {
            'auth.ldap': {
              enabled: true,
              config_file: '/etc/grafana/ldap.toml',
              allow_sign_up: true,
            },
          },
        },
        ldap: |||
          [[servers]]
          host = "127.0.0.1"
          port = 389
          use_ssl = false
          start_tls = false
          ssl_skip_verify = false

          bind_dn = "cn=admins,dc=example,dc=com"
          bind_password = 'grafana'

          search_filter = "(cn=%s)"
          search_base_dns = ["dc=example,dc=com"]
        |||,
      },
    },
  };

{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
