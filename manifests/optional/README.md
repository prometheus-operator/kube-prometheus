You can compose things from this folder in your kustomization.yaml;


- annotations-exporter: enable prometheus to scrape

  annotations:
    prometheus.io/path: "/metrics"
    prometheus.io/scrape: 'true'
    prometheus.io/port: '9402'

  on pods and services

- grafana — a sample grafana deployment
- grafana-dashboards - dashboards for the non-optional exporters for prometheus-operator
- istio-exporter - sample exporters for Istio
- prometheus-adapter - allow HoritontalPodAutoscaler to act on Prometheus metrics (instead of kube-state-metrics)
- what-about-this — I haven't investigeted whether these are by default in kube-state-metrics