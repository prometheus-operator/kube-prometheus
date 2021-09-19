local patch(ports) = {
  spec+: {
    ports: ports,
    type: 'NodePort',
  },
};

{
  prometheus+: {
    service+: patch([{ name: 'web', port: 9090, targetPort: 'web', nodePort: 30900 }]),
  },
  alertmanager+: {
    service+: patch([{ name: 'web', port: 9093, targetPort: 'web', nodePort: 30903 }]),
  },
  grafana+: {
    service+: patch([{ name: 'http', port: 3000, targetPort: 'http', nodePort: 30902 }]),
  },
}
