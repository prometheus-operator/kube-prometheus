# Grafana Monitoring Quick Start Guide

This guide helps you quickly understand and use Grafana self-monitoring in kube-prometheus.

## TL;DR

**Grafana monitoring is already enabled by default in kube-prometheus.** No additional configuration is required.

## What You Get

When you deploy kube-prometheus, you automatically get:

1. **Metrics Collection** - Grafana metrics scraped every 15 seconds
2. **Alerts** - `GrafanaRequestsFailing` alert for 5xx errors
3. **Dashboard** - Grafana Overview dashboard showing health and performance
4. **Recording Rules** - Pre-aggregated metrics for efficient querying

## Verify It's Working

### 1. Check the Manifests

```bash
# List Grafana monitoring resources
ls -1 manifests/grafana-*.yaml | grep -E "(prometheusRule|serviceMonitor)"
```

Expected output:
```
manifests/grafana-prometheusRule.yaml
manifests/grafana-serviceMonitor.yaml
```

### 2. Run the Validation Script

```bash
# Validate Grafana monitoring configuration
./scripts/validate-grafana-monitoring.sh
```

Expected output:
```
✓ All critical validations passed!
```

### 3. Query Grafana Metrics in Prometheus

After deploying kube-prometheus:

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090
```

Open http://localhost:9090 and run:
```promql
grafana_http_request_duration_seconds_count
```

You should see metrics from your Grafana instance.

### 4. View the Dashboard

1. Access Grafana UI
2. Navigate to Dashboards
3. Find "Grafana Overview" dashboard
4. View Grafana health metrics

## Common Customizations

### Add Team Labels to Alerts

Edit your jsonnet configuration:

```jsonnet
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    grafana+: {
      mixin+: {
        ruleLabels: {
          team: 'platform',
        },
      },
    },
  },
};
```

### Change Alert Threshold

See `examples/grafana-monitoring-customization.jsonnet` for advanced customization.

## Documentation

- **Full Guide:** `docs/customizations/grafana-monitoring.md`
- **Runbook:** `docs/runbooks/grafana.md`
- **Examples:**
  - `examples/grafana-monitoring-simple.jsonnet`
  - `examples/grafana-monitoring-customization.jsonnet`

## Troubleshooting

### No Grafana Metrics Appearing

1. Check if ServiceMonitor exists:
   ```bash
   kubectl get servicemonitor -n monitoring grafana
   ```

2. Verify Grafana is running:
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
   ```

3. Check Prometheus targets:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090
   ```
   Open http://localhost:9090/targets and search for "grafana"

### Alert Not Firing

1. Check PrometheusRule exists:
   ```bash
   kubectl get prometheusrule -n monitoring grafana-rules
   ```

2. Verify rule is loaded in Prometheus:
   - Port-forward to Prometheus (see above)
   - Go to Status → Rules
   - Search for "GrafanaRequestsFailing"

## Getting Help

- **Validation Script:** `./scripts/validate-grafana-monitoring.sh`
- **Runbook:** `docs/runbooks/grafana.md`
- **Full Documentation:** `docs/customizations/grafana-monitoring.md`

## Summary

Grafana monitoring is a first-class component in kube-prometheus:
- ✅ Enabled by default
- ✅ Production-ready
- ✅ Fully documented
- ✅ Easy to customize

No action is required unless you want to customize the default behavior.
