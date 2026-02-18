# Grafana Self-Monitoring

kube-prometheus includes comprehensive self-monitoring for Grafana using the official [Grafana mixin](https://github.com/grafana/grafana/tree/main/grafana-mixin). This provides alerts, recording rules, and dashboards to monitor the health and performance of your Grafana instances.

## Table of Contents

- [What's Included](#whats-included)
- [How It Works](#how-it-works)
- [Configuration](#configuration)
- [Customization](#customization)
- [Metrics Collected](#metrics-collected)
- [Alerts Reference](#alerts-reference)
- [Dashboards](#dashboards)
- [Troubleshooting](#troubleshooting)

## What's Included

The Grafana monitoring integration provides:

1. **PrometheusRule** - Alert rules and recording rules for Grafana metrics
2. **ServiceMonitor** - Automatic scraping of Grafana `/metrics` endpoint
3. **Grafana Overview Dashboard** - Visual dashboard for Grafana performance and health
4. **Recording Rules** - Pre-aggregated metrics for efficient querying

## How It Works

The Grafana component in kube-prometheus automatically:

1. Imports the official Grafana mixin from the [grafana/grafana repository](https://github.com/grafana/grafana/tree/main/grafana-mixin)
2. Generates a `PrometheusRule` custom resource with alerts and recording rules
3. Creates a `ServiceMonitor` to scrape Grafana's metrics endpoint every 15 seconds
4. Includes the Grafana Overview dashboard in the dashboard ConfigMaps

The integration is built directly into the Grafana component (`jsonnet/kube-prometheus/components/grafana.libsonnet`), ensuring that Grafana monitoring is always available when you deploy kube-prometheus.

## Configuration

### Default Configuration

Grafana monitoring is enabled by default with these settings:

- **Metrics scrape interval**: 15 seconds
- **Metrics endpoint**: `http` port (Grafana service port 3000)
- **Runbook URL pattern**: `https://runbooks.prometheus-operator.dev/runbooks/grafana/%s`

### Enabling Grafana Metrics

Grafana exposes metrics on its main HTTP port by default. No additional configuration is required in Grafana itself - the metrics are available at `http://grafana:3000/metrics`.

The ServiceMonitor automatically discovers and scrapes Grafana pods based on the label selector:
```yaml
matchLabels:
  app.kubernetes.io/name: grafana
```

## Customization

### Customizing Alert Labels

You can add custom labels to Grafana alerts by modifying the `mixin.ruleLabels` configuration:

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') + {
    values+:: {
      grafana+: {
        mixin+: {
          ruleLabels: {
            team: 'platform',
            severity_page: 'true',
          },
        },
      },
    },
  };

{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

### Customizing Runbook URLs

Override the runbook URL pattern to point to your own documentation:

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') + {
    values+:: {
      grafana+: {
        mixin+: {
          _config+: {
            runbookURLPattern: 'https://your-runbooks.example.com/grafana/%s',
          },
        },
      },
    },
  };

{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

### Adjusting Scrape Interval

Modify the ServiceMonitor scrape interval:

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') + {
    grafana+: {
      serviceMonitor+: {
        spec+: {
          endpoints: [{
            port: 'http',
            interval: '30s',  // Change from default 15s
          }],
        },
      },
    },
  };

{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

### Disabling Specific Alerts

To disable specific Grafana alerts, you can exclude them from the generated PrometheusRule:

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') + {
    grafana+: {
      prometheusRule+: {
        spec+: {
          groups: std.map(
            function(group) group {
              rules: std.filter(
                function(rule)
                  !std.objectHas(rule, 'alert') ||
                  rule.alert != 'GrafanaRequestsFailing',  // Alert to disable
                group.rules
              ),
            },
            super.groups
          ),
        },
      },
    },
  };

{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

## Metrics Collected

The Grafana ServiceMonitor collects all metrics exposed by Grafana, including:

### HTTP Metrics
- `grafana_http_request_duration_seconds_bucket` - Request duration histogram
- `grafana_http_request_duration_seconds_sum` - Total request duration
- `grafana_http_request_duration_seconds_count` - Total number of requests
- `grafana_http_request_total` - Total HTTP requests by status code

### Application Metrics
- `grafana_build_info` - Grafana version and build information
- `grafana_stat_totals_dashboard` - Total number of dashboards
- `grafana_stat_totals_datasource` - Total number of datasources
- `grafana_stat_totals_user` - Total number of users
- `grafana_stat_totals_org` - Total number of organizations
- `grafana_stat_totals_playlist` - Total number of playlists

### Alerting Metrics
- `grafana_alerting_result_total` - Total alert evaluation results
- `grafana_alerting_active_alerts` - Number of active alerts
- `grafana_alerting_notification_sent_total` - Total notifications sent

### Database Metrics
- `grafana_database_connected` - Database connection status
- `grafana_database_open_connections` - Number of open database connections

## Alerts Reference

### GrafanaRequestsFailing

**Severity**: Warning

**Description**: Fires when more than 50% of requests to Grafana are returning 5xx errors for 5 minutes.

**Impact**: Users may be experiencing errors when accessing Grafana dashboards.

**Query**:
```promql
100 * sum without (status_code) (
  namespace_job_handler_statuscode:grafana_http_request_duration_seconds_count:rate5m{
    handler!~"/api/datasources/proxy/:id.*|/api/ds/query|/api/tsdb/query",
    status_code=~"5.."
  }
)
/
sum without (status_code) (
  namespace_job_handler_statuscode:grafana_http_request_duration_seconds_count:rate5m{
    handler!~"/api/datasources/proxy/:id.*|/api/ds/query|/api/tsdb/query"
  }
)
> 50
```

**Troubleshooting**:

1. Check Grafana pod logs:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
   ```

2. Verify Grafana pod status:
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
   ```

3. Check for database connectivity issues:
   ```bash
   kubectl exec -n monitoring deploy/grafana -- grafana-cli admin data-migration list
   ```

4. Review recent configuration changes that might have caused errors

5. Check resource utilization (CPU/memory):
   ```bash
   kubectl top pods -n monitoring -l app.kubernetes.io/name=grafana
   ```

## Recording Rules

The Grafana mixin includes recording rules that pre-aggregate metrics for efficient querying:

### namespace_job_handler_statuscode:grafana_http_request_duration_seconds_count:rate5m

Pre-aggregated 5-minute rate of Grafana HTTP requests, grouped by:
- namespace
- job
- handler (endpoint)
- status_code

This recording rule is used by the `GrafanaRequestsFailing` alert to efficiently calculate error rates.

## Dashboards

### Grafana Overview Dashboard

The Grafana Overview dashboard provides visibility into:

1. **System Information**
   - Grafana version
   - Instance information
   - Active alerts

2. **Request Metrics**
   - Request rate by status code
   - Request duration (p50, p99)
   - Average request latency

3. **Resource Usage**
   - Dashboard count
   - Datasource count
   - User count

4. **Database Health**
   - Connection status
   - Open connections

**Accessing the Dashboard**:

The dashboard is automatically imported into Grafana as "Grafana Overview" and can be found in the default dashboard folder.

## Troubleshooting

### ServiceMonitor Not Scraping Metrics

**Symptoms**: No Grafana metrics appearing in Prometheus

**Diagnosis**:
```bash
# Check if ServiceMonitor exists
kubectl get servicemonitor -n monitoring grafana

# Verify Prometheus is selecting this ServiceMonitor
kubectl get prometheus -n monitoring -o yaml | grep -A 10 serviceMonitorSelector

# Check if Grafana service has correct labels
kubectl get svc -n monitoring grafana -o yaml | grep -A 5 labels
```

**Solution**: Ensure the Grafana service has the label `app.kubernetes.io/name: grafana`

### Metrics Endpoint Not Available

**Symptoms**: ServiceMonitor exists but scrape targets show "down"

**Diagnosis**:
```bash
# Test metrics endpoint directly
kubectl port-forward -n monitoring svc/grafana 3000:3000
curl http://localhost:3000/metrics
```

**Solution**: Verify Grafana is running and healthy. Grafana exposes metrics by default on its main HTTP port.

### Alerts Not Firing

**Symptoms**: PrometheusRule exists but alerts don't appear in Alertmanager

**Diagnosis**:
```bash
# Verify PrometheusRule exists and is valid
kubectl get prometheusrule -n monitoring grafana-rules -o yaml

# Check Prometheus rule status
kubectl exec -n monitoring prometheus-k8s-0 -- promtool check rules /etc/prometheus/rules/prometheus-k8s-rulefiles-0/*.yaml
```

**Solution**: Check Prometheus logs for rule evaluation errors

### Dashboard Not Appearing

**Symptoms**: Grafana Overview dashboard not visible in Grafana UI

**Diagnosis**:
```bash
# Check if dashboard ConfigMap exists
kubectl get configmap -n monitoring -l app.kubernetes.io/name=grafana | grep dashboard

# Verify dashboard sidecar is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o yaml | grep -A 10 grafana-sc-dashboard
```

**Solution**: Ensure Grafana dashboard sidecar is configured to watch for dashboards in ConfigMaps

## Additional Resources

- [Grafana Metrics](https://grafana.com/docs/grafana/latest/administration/view-server/internal-metrics/)
- [Grafana Mixin Source](https://github.com/grafana/grafana/tree/main/grafana-mixin)
- [Prometheus Operator ServiceMonitor](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/getting-started.md#deploying-a-sample-application)
- [kube-prometheus Customization Guide](../customizing.md)

## See Also

- [Monitoring Grafana](https://grafana.com/docs/grafana/latest/administration/monitor-grafana/)
- [Customizing kube-prometheus](../customizing.md)
- [Developing Prometheus Rules and Grafana Dashboards](./developing-prometheus-rules-and-grafana-dashboards.md)
