#!/usr/bin/env bash

# Grafana Monitoring Integration Test
# Tests Grafana self-monitoring in a local Kubernetes cluster

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="${NAMESPACE:-monitoring}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

section() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    log_success "kubectl is installed"
}

# Check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_info "Start a local cluster with: minikube start or kind create cluster"
        exit 1
    fi
    log_success "Connected to Kubernetes cluster: $(kubectl config current-context)"
}

# Validate manifests before applying
validate_manifests() {
    section "Validating Manifests"

    if ! "$SCRIPT_DIR/validate-grafana-monitoring.sh"; then
        log_error "Manifest validation failed"
        exit 1
    fi
}

# Apply manifests to cluster
apply_manifests() {
    section "Applying kube-prometheus Manifests"

    log_info "Creating namespace and CRDs..."
    kubectl apply --server-side -f "$ROOT_DIR/manifests/setup" 2>&1 | head -20

    log_info "Waiting for CRDs to be established..."
    kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=$NAMESPACE --timeout=60s

    log_info "Applying monitoring stack..."
    kubectl apply -f "$ROOT_DIR/manifests/" 2>&1 | grep -E "(created|configured|unchanged)" | head -20

    log_success "Manifests applied successfully"
}

# Wait for Grafana to be ready
wait_for_grafana() {
    section "Waiting for Grafana"

    log_info "Waiting for Grafana deployment to be available..."
    kubectl wait --for=condition=Available --timeout=300s deployment/grafana -n $NAMESPACE

    log_success "Grafana is ready"
}

# Check ServiceMonitor
check_service_monitor() {
    section "Checking ServiceMonitor"

    if kubectl get servicemonitor grafana -n $NAMESPACE &> /dev/null; then
        log_success "ServiceMonitor exists"

        # Show details
        log_info "ServiceMonitor configuration:"
        kubectl get servicemonitor grafana -n $NAMESPACE -o jsonpath='{.spec.endpoints[0]}' | python3 -m json.tool
    else
        log_error "ServiceMonitor not found"
        return 1
    fi
}

# Check PrometheusRule
check_prometheus_rule() {
    section "Checking PrometheusRule"

    if kubectl get prometheusrule grafana-rules -n $NAMESPACE &> /dev/null; then
        log_success "PrometheusRule exists"

        # Count alerts
        local alert_count=$(kubectl get prometheusrule grafana-rules -n $NAMESPACE -o json | jq '[.spec.groups[].rules[] | select(has("alert"))] | length')
        log_info "Alert count: $alert_count"

        # List alerts
        log_info "Alerts defined:"
        kubectl get prometheusrule grafana-rules -n $NAMESPACE -o json | jq -r '.spec.groups[].rules[] | select(has("alert")) | "  - " + .alert'
    else
        log_error "PrometheusRule not found"
        return 1
    fi
}

# Check if Prometheus is scraping Grafana
check_prometheus_targets() {
    section "Checking Prometheus Targets"

    log_info "Checking if Prometheus is scraping Grafana..."

    # Port-forward to Prometheus
    kubectl port-forward -n $NAMESPACE svc/prometheus-k8s 9090:9090 &
    local PF_PID=$!
    sleep 3

    # Check targets API
    local targets=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job == "grafana") | .health')

    kill $PF_PID 2>/dev/null || true

    if [[ "$targets" == "up" ]]; then
        log_success "Prometheus is successfully scraping Grafana"
    else
        log_warn "Grafana target status: $targets (may still be starting up)"
    fi
}

# Query Grafana metrics from Prometheus
check_metrics() {
    section "Checking Grafana Metrics"

    log_info "Querying Grafana metrics from Prometheus..."

    # Port-forward to Prometheus
    kubectl port-forward -n $NAMESPACE svc/prometheus-k8s 9090:9090 &
    local PF_PID=$!
    sleep 3

    # Query for Grafana metrics
    local metric_count=$(curl -s 'http://localhost:9090/api/v1/label/__name__/values' | jq -r '.data[] | select(startswith("grafana_"))' | wc -l)

    kill $PF_PID 2>/dev/null || true

    if [[ $metric_count -gt 0 ]]; then
        log_success "Found $metric_count Grafana metrics in Prometheus"
        log_info "Sample metrics:"
        curl -s 'http://localhost:9090/api/v1/label/__name__/values' 2>/dev/null | jq -r '.data[] | select(startswith("grafana_"))' | head -5 | while read metric; do
            echo "    - $metric"
        done
    else
        log_warn "No Grafana metrics found yet (may need more time)"
    fi
}

# Check Grafana dashboard
check_dashboard() {
    section "Checking Grafana Dashboard"

    log_info "Checking if Grafana Overview dashboard exists..."

    # Port-forward to Grafana
    kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000 &
    local PF_PID=$!
    sleep 3

    # Search for dashboard (using default admin credentials)
    local dashboard_search=$(curl -s -u admin:admin 'http://localhost:3000/api/search?query=grafana' 2>/dev/null || echo "[]")
    local dashboard_count=$(echo "$dashboard_search" | jq '. | length')

    kill $PF_PID 2>/dev/null || true

    if [[ $dashboard_count -gt 0 ]]; then
        log_success "Found Grafana monitoring dashboards"
        echo "$dashboard_search" | jq -r '.[] | "  - " + .title'
    else
        log_warn "Grafana Overview dashboard not found (check dashboard provisioning)"
    fi
}

# Test alert rules
test_alert_rules() {
    section "Testing Alert Rules"

    log_info "Verifying alert rules are loaded in Prometheus..."

    kubectl port-forward -n $NAMESPACE svc/prometheus-k8s 9090:9090 &
    local PF_PID=$!
    sleep 3

    # Check for Grafana alert rules
    local alert_rules=$(curl -s 'http://localhost:9090/api/v1/rules' | jq -r '.data.groups[] | select(.name | contains("Grafana")) | .name')

    kill $PF_PID 2>/dev/null || true

    if [[ -n "$alert_rules" ]]; then
        log_success "Grafana alert rules loaded:"
        echo "$alert_rules" | while read rule; do
            echo "  - $rule"
        done
    else
        log_warn "No Grafana alert rules found"
    fi
}

# Print access information
print_access_info() {
    section "Access Information"

    echo ""
    echo "To access Grafana UI:"
    echo "  kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
    echo "  Open: http://localhost:3000"
    echo "  Default credentials: admin/admin"
    echo ""
    echo "To access Prometheus UI:"
    echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-k8s 9090:9090"
    echo "  Open: http://localhost:9090"
    echo ""
    echo "To view Grafana metrics:"
    echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-k8s 9090:9090"
    echo "  Query: grafana_http_request_duration_seconds_count"
    echo ""
    echo "To check alert status:"
    echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-k8s 9090:9090"
    echo "  Open: http://localhost:9090/alerts"
    echo ""
}

# Cleanup function
cleanup() {
    section "Cleanup"

    log_info "To remove the monitoring stack:"
    echo "  kubectl delete -f $ROOT_DIR/manifests/"
    echo "  kubectl delete -f $ROOT_DIR/manifests/setup"
    echo ""
    log_warn "This will remove all monitoring components including Prometheus, Grafana, and Alertmanager"
}

# Main execution
main() {
    echo "========================================"
    echo "Grafana Monitoring Integration Test"
    echo "========================================"
    echo ""

    # Pre-flight checks
    check_kubectl
    check_cluster

    # Validate before applying
    validate_manifests

    # Ask for confirmation
    echo ""
    read -p "Apply kube-prometheus to cluster '$(kubectl config current-context)'? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted by user"
        exit 0
    fi

    # Apply and test
    apply_manifests
    wait_for_grafana

    # Run checks
    check_service_monitor
    check_prometheus_rule

    # Wait a bit for metrics to be scraped
    log_info "Waiting 30 seconds for metrics collection..."
    sleep 30

    check_prometheus_targets
    check_metrics
    check_dashboard
    test_alert_rules

    # Print summary
    section "Test Summary"
    log_success "All tests completed!"
    echo ""

    print_access_info
    cleanup
}

# Run main function
main "$@"
