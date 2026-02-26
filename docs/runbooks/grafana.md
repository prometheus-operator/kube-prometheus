# Grafana Runbooks

This document contains runbooks for Grafana-related alerts in kube-prometheus.

## Table of Contents

- [GrafanaRequestsFailing](#grafanarequestsfailing)
- [General Troubleshooting](#general-troubleshooting)
- [Useful Queries](#useful-queries)

## GrafanaRequestsFailing

### Summary

More than 50% of HTTP requests to Grafana are returning 5xx server errors.

### Severity

Warning

### Impact

- Users cannot access Grafana dashboards reliably
- Dashboard queries may be failing
- Data visualization is unavailable or unreliable
- Alerting notifications from Grafana may be affected

### Diagnosis

#### 1. Check Alert Details

First, examine the alert to identify which Grafana instance and endpoint are affected:

```promql
# View current error rate by handler
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
```

#### 2. Check Grafana Pod Status

```bash
# Check if Grafana pods are running
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Check pod events
kubectl describe pods -n monitoring -l app.kubernetes.io/name=grafana

# Check pod resource usage
kubectl top pods -n monitoring -l app.kubernetes.io/name=grafana
```

#### 3. Review Grafana Logs

```bash
# View recent logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=100

# Follow logs in real-time
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f

# Search for errors
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=1000 | grep -i "error\|fatal\|panic"
```

Common error patterns to look for:
- Database connection errors
- Out of memory errors
- Permission/authorization errors
- Plugin errors
- Data source connection failures

#### 4. Check Database Connectivity

If using an external database (PostgreSQL, MySQL):

```bash
# Test database connection from Grafana pod
kubectl exec -n monitoring deploy/grafana -- nc -zv <database-host> <database-port>

# Check database credentials in secret
kubectl get secret -n monitoring grafana -o yaml
```

#### 5. Review Resource Utilization

```bash
# Check memory usage
kubectl top pods -n monitoring -l app.kubernetes.io/name=grafana

# Check if pod is being OOMKilled
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[*].status.containerStatuses[*].lastState}'
```

#### 6. Check Configuration

```bash
# Review Grafana configuration
kubectl get configmap -n monitoring grafana-config -o yaml

# Check for recent configuration changes
kubectl describe configmap -n monitoring grafana-config
```

### Common Causes and Solutions

#### Cause 1: Database Connection Issues

**Symptoms:**
- Logs show "database connection failed" or "connection refused"
- Grafana repeatedly restarts
- Errors mentioning "sql" or "database"

**Solution:**

1. Verify database is running and accessible:
   ```bash
   kubectl get pods -n <database-namespace>
   ```

2. Check database credentials:
   ```bash
   kubectl get secret -n monitoring grafana -o yaml
   ```

3. Test connectivity from Grafana pod:
   ```bash
   kubectl exec -n monitoring deploy/grafana -- nc -zv <db-host> <db-port>
   ```

4. Review database logs for connection limit or authentication errors

5. If using SQLite (default), check PVC status:
   ```bash
   kubectl get pvc -n monitoring
   ```

#### Cause 2: Memory Pressure / OOMKilled

**Symptoms:**
- Pod restarts frequently
- `kubectl describe pod` shows OOMKilled
- Logs show out-of-memory errors

**Solution:**

1. Check current memory limits:
   ```bash
   kubectl get deployment -n monitoring grafana -o jsonpath='{.spec.template.spec.containers[0].resources}'
   ```

2. Increase memory limits in your configuration:
   ```jsonnet
   local kp = (import 'kube-prometheus/main.libsonnet') + {
     values+:: {
       grafana+: {
         resources: {
           requests: { cpu: '100m', memory: '256Mi' },
           limits: { cpu: '500m', memory: '512Mi' },
         },
       },
     },
   };
   ```

3. Rebuild and apply manifests

#### Cause 3: Plugin Errors

**Symptoms:**
- Errors mentioning specific plugins in logs
- Specific panels or dashboards failing
- Plugin initialization errors

**Solution:**

1. Identify failing plugin from logs:
   ```bash
   kubectl logs -n monitoring deploy/grafana | grep -i "plugin"
   ```

2. Check plugin status in Grafana UI:
   - Navigate to Configuration → Plugins
   - Look for disabled or error state plugins

3. Restart Grafana to reload plugins:
   ```bash
   kubectl rollout restart deployment -n monitoring grafana
   ```

4. If problem persists, consider disabling the problematic plugin

#### Cause 4: Data Source Connection Failures

**Symptoms:**
- Errors accessing specific dashboards
- "Failed to query data source" errors
- Timeout errors in logs

**Solution:**

1. Test data source connectivity from Grafana:
   - Go to Configuration → Data Sources
   - Click "Test" on each data source

2. Check Prometheus availability:
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
   ```

3. Verify network policies allow Grafana → Prometheus:
   ```bash
   kubectl get networkpolicy -n monitoring
   ```

4. Test connectivity from Grafana pod:
   ```bash
   kubectl exec -n monitoring deploy/grafana -- wget -O- http://prometheus-k8s:9090/-/healthy
   ```

#### Cause 5: Configuration Errors

**Symptoms:**
- Grafana fails to start after configuration change
- Specific features not working
- Authentication/authorization errors

**Solution:**

1. Review recent configuration changes:
   ```bash
   kubectl get events -n monitoring --sort-by='.lastTimestamp'
   ```

2. Validate configuration syntax:
   ```bash
   kubectl exec -n monitoring deploy/grafana -- grafana-server -config /etc/grafana/grafana.ini -homepath /usr/share/grafana check-config
   ```

3. Revert to previous working configuration if needed:
   ```bash
   kubectl rollout undo deployment -n monitoring grafana
   ```

#### Cause 6: High Dashboard Load

**Symptoms:**
- Slow response times
- Timeouts on complex dashboards
- High CPU usage

**Solution:**

1. Identify slow queries in Grafana logs

2. Optimize dashboard queries:
   - Reduce time range
   - Add query time limits
   - Use recording rules for complex queries

3. Increase resources if needed (see Cause 2)

4. Enable query caching in Grafana configuration

### Escalation

If the issue persists after trying the above solutions:

1. Collect diagnostic information:
   ```bash
   # Gather logs
   kubectl logs -n monitoring deploy/grafana --previous > grafana-previous.log
   kubectl logs -n monitoring deploy/grafana > grafana-current.log

   # Gather pod description
   kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana > grafana-pod-describe.txt

   # Gather events
   kubectl get events -n monitoring --sort-by='.lastTimestamp' > grafana-events.txt
   ```

2. Check Grafana GitHub issues for known bugs matching your symptoms

3. Contact your platform team with:
   - Alert details (namespace, job, handler)
   - Log snippets showing errors
   - Recent changes to Grafana configuration
   - Grafana version information

## General Troubleshooting

### Access Grafana Metrics Endpoint

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# View metrics
curl http://localhost:3000/metrics
```

### Check Grafana Health

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Check health endpoint
curl http://localhost:3000/api/health
```

Expected response:
```json
{
  "commit": "...",
  "database": "ok",
  "version": "..."
}
```

### Restart Grafana

```bash
# Rolling restart
kubectl rollout restart deployment -n monitoring grafana

# Watch rollout status
kubectl rollout status deployment -n monitoring grafana
```

### Enable Debug Logging

Temporarily enable debug logging to get more information:

```bash
# Edit ConfigMap to set log level to debug
kubectl edit configmap -n monitoring grafana-config

# Change [log] level to debug, then restart Grafana
kubectl rollout restart deployment -n monitoring grafana
```

Remember to revert to info level after troubleshooting.

## Useful Queries

### Current Error Rate by Endpoint

```promql
100 * sum without (status_code) (
  rate(grafana_http_request_duration_seconds_count{status_code=~"5.."}[5m])
)
/
sum without (status_code) (
  rate(grafana_http_request_duration_seconds_count[5m])
)
```

### Request Rate by Status Code

```promql
sum by (status_code) (
  rate(grafana_http_request_duration_seconds_count[5m])
)
```

### P95 Request Latency

```promql
histogram_quantile(0.95,
  sum by (le) (
    rate(grafana_http_request_duration_seconds_bucket[5m])
  )
)
```

### Top Slowest Endpoints

```promql
topk(10,
  sum by (handler) (
    rate(grafana_http_request_duration_seconds_sum[5m])
  )
  /
  sum by (handler) (
    rate(grafana_http_request_duration_seconds_count[5m])
  )
)
```

### Dashboard Count

```promql
grafana_stat_totals_dashboard
```

### Active Alerts in Grafana

```promql
sum(grafana_alerting_result_total{state="alerting"})
```

### Database Connection Status

```promql
grafana_database_connected
```

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Grafana Metrics](https://grafana.com/docs/grafana/latest/administration/view-server/internal-metrics/)
- [Grafana Troubleshooting](https://grafana.com/docs/grafana/latest/troubleshooting/)
- [kube-prometheus Grafana Monitoring Documentation](../customizations/grafana-monitoring.md)
