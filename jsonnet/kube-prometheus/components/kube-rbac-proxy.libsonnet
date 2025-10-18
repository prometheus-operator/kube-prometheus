local defaults = {
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  namespace:: error 'must provide namespace',
  image:: error 'must provide image',
  ports:: error 'must provide ports',
  secureListenAddress:: error 'must provide secureListenAddress',
  upstream:: error 'must provide upstream',
  resources:: {
    requests: { cpu: '10m', memory: '20Mi' },
    limits: { cpu: '20m', memory: '40Mi' },
  },
  tlsCipherSuites:: [
    'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',  // required by h2: http://golang.org/cl/30721
    'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256',  // required by h2: http://golang.org/cl/30721

    // 'TLS_RSA_WITH_RC4_128_SHA',                // insecure: https://access.redhat.com/security/cve/cve-2013-2566
    // 'TLS_RSA_WITH_3DES_EDE_CBC_SHA',           // insecure: https://access.redhat.com/articles/2548661
    // 'TLS_RSA_WITH_AES_128_CBC_SHA',            // disabled by h2
    // 'TLS_RSA_WITH_AES_256_CBC_SHA',            // disabled by h2
    // 'TLS_RSA_WITH_AES_128_CBC_SHA256',         // insecure: https://access.redhat.com/security/cve/cve-2013-0169
    // 'TLS_RSA_WITH_AES_128_GCM_SHA256',         // disabled by h2
    // 'TLS_RSA_WITH_AES_256_GCM_SHA384',         // disabled by h2
    // 'TLS_ECDHE_ECDSA_WITH_RC4_128_SHA',        // insecure: https://access.redhat.com/security/cve/cve-2013-2566
    // 'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA',    // disabled by h2
    // 'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA',    // disabled by h2
    // 'TLS_ECDHE_RSA_WITH_RC4_128_SHA',          // insecure: https://access.redhat.com/security/cve/cve-2013-2566
    // 'TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA',     // insecure: https://access.redhat.com/articles/2548661
    // 'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA',      // disabled by h2
    // 'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA',      // disabled by h2
    // 'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256', // insecure: https://access.redhat.com/security/cve/cve-2013-0169
    // 'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256',   // insecure: https://access.redhat.com/security/cve/cve-2013-0169

    // disabled by h2 means: https://github.com/golang/net/blob/e514e69ffb8bc3c76a71ae40de0118d794855992/http2/ciphers.go

    'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
    'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384',
    'TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305',
    'TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305',
  ],
  // Corresponds to KRP's --ignore-paths flag.
  // Some components (for e.g., KSM) may utilize the flag to allow for communication with external parties in scenarios
  // where the originating request(s) cannot be modified to the proxy's expectations, and thus, are passed through, as
  // is, to certain endpoints that they target, without the proxy's intervention. The kubelet, in KSM's case, can thus
  // query health probe endpoints without being blocked by KRP, thus allowing for http-based probes over exec-based
  // ones.
  ignorePaths:: [],
};


function(params) {
  local krp = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(krp._config.resources),

  name: krp._config.name,
  image: krp._config.image,
  args: [
          '--secure-listen-address=' + krp._config.secureListenAddress,
          '--tls-cipher-suites=' + std.join(',', krp._config.tlsCipherSuites),
          '--upstream=' + krp._config.upstream,
        ]  // Optionals.
        + if std.length(krp._config.ignorePaths) > 0 then ['--ignore-paths=' + std.join(',', krp._config.ignorePaths)] else defaults.ignorePaths,
  resources: krp._config.resources,
  ports: krp._config.ports,
  securityContext: {
    runAsUser: 65532,
    runAsGroup: 65532,
    runAsNonRoot: true,
    allowPrivilegeEscalation: false,
    readOnlyRootFilesystem: true,
    capabilities: { drop: ['ALL'] },
    seccompProfile: { type: 'RuntimeDefault' },
  },
}
