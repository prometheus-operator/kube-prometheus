{
  values+:: {
    pa+: {
      profilesCM: 'prometheus-adapter-audit-profiles',
      auditProfile: 'metadata',
      auditLogPath: '/var/log/adapter',
      auditProfilesDir: '/etc/audit',
      auditVolume: 'audit-log',
      auditLogMaxSize: '100',
    },
  },
  profile(level):: {
    apiVersion: 'audit.k8s.io/v1',
    kind: 'Policy',
    metadata: {
      name: level,
    },
    // omit stage RequestReceived to avoid duplication of logs for both stages
    // RequestReceived and ResponseComplete
    omitStages: ['RequestReceived'],
    rules: [{ level: level }],
  },

  enableAudit(c):: c {
    local profileFile = '%s/%s-profile.yaml' % [
      $.values.pa.auditProfilesDir,
      $.values.pa.auditProfile,
    ],

    args+: [
      '--audit-profile-file=%s' % profileFile,
      '--audit-log-path=%s' % $.values.pa.auditLogPath,
      '--audit-log-maxsize=%s' % $.values.pa.auditLogMaxSize,
    ],
    volumeMounts+: [{
      mountPath: $.values.pa.auditProfilesDir,
      name: $.values.pa.profilesCM,
      readOnly: true,
    }, {
      mountPath: $.values.pa.auditLogPath,
      name: $.values.pa.auditVolume,
      readOnly: false,
    }],

  },
  prometheusAdapter+: {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers:
              std.map(
                function(c)
                  if c.name == 'prometheus-adapter' then
                    $.enableAudit(c)
                  else
                    c,
                super.containers,
              ),

            volumes+: [{
              name: $.values.pa.auditVolume,
              emptyDir: {},
            }, {
              name: $.values.pa.profilesCM,
              configMap: {
                name: $.values.pa.profilesCM,
              },
            }],
          },  // spec
        },  // template
      },  // spec
    },  // deployment

    configmapAuditProfiles: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: $.values.pa.profilesCM,
        namespace: $.values.common.namespace,
      },
      data: {
        // TODO(sthaha): use quote_keys=false when version > 0.17 is released
        // generate <level>-profile.yaml for all log levels
        [std.asciiLower(x) + '-profile.yaml']: std.manifestYamlDoc($.profile(x))
        for x in ['None', 'Metadata', 'Request', 'RequestResponse']
      },
    },
  },  // pa
}
