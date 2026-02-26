#!/usr/bin/env bash

# Grafana Monitoring Validation Script
# This script validates that Grafana self-monitoring is properly configured in kube-prometheus

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Track validation results
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL_COUNT++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN_COUNT++))
}

info() {
    echo -e "ℹ $1"
}

section() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# Check if manifests directory exists
check_manifests_exist() {
    section "Checking Manifests Directory"

    if [ ! -d "$ROOT_DIR/manifests" ]; then
        fail "Manifests directory does not exist. Run 'make generate' first."
        return 1
    fi

    if [ -z "$(ls -A "$ROOT_DIR/manifests")" ]; then
        warn "Manifests directory is empty. Run 'make generate' to build manifests."
        return 1
    fi

    pass "Manifests directory exists and contains files"
}

# Validate Grafana component configuration
check_grafana_component() {
    section "Validating Grafana Component"

    local component_file="$ROOT_DIR/jsonnet/kube-prometheus/components/grafana.libsonnet"

    if [ ! -f "$component_file" ]; then
        fail "Grafana component file not found: $component_file"
        return 1
    fi
    pass "Grafana component file exists"

    # Check for mixin import
    if grep -q "github.com/grafana/grafana/grafana-mixin/mixin.libsonnet" "$component_file"; then
        pass "Grafana mixin is imported in component"
    else
        fail "Grafana mixin import not found in component"
    fi

    # Check for prometheusRule definition
    if grep -q "prometheusRule:" "$component_file"; then
        pass "PrometheusRule definition found in component"
    else
        fail "PrometheusRule definition not found in component"
    fi

    # Check for serviceMonitor definition
    if grep -q "serviceMonitor:" "$component_file"; then
        pass "ServiceMonitor definition found in component"
    else
        fail "ServiceMonitor definition not found in component"
    fi
}

# Check jsonnet dependencies
check_dependencies() {
    section "Validating Dependencies"

    local jsonnetfile="$ROOT_DIR/jsonnet/kube-prometheus/jsonnetfile.json"

    if [ ! -f "$jsonnetfile" ]; then
        fail "jsonnetfile.json not found"
        return 1
    fi
    pass "jsonnetfile.json exists"

    # Check for Grafana mixin dependency
    if grep -q "github.com/grafana/grafana" "$jsonnetfile"; then
        pass "Grafana mixin dependency found in jsonnetfile.json"
    else
        fail "Grafana mixin dependency not found in jsonnetfile.json"
    fi

    # Check for kubernetes-mixin (for runbook links)
    if grep -q "github.com/kubernetes-monitoring/kubernetes-mixin" "$jsonnetfile"; then
        pass "Kubernetes mixin dependency found (required for runbook links)"
    else
        warn "Kubernetes mixin dependency not found"
    fi
}

# Validate generated PrometheusRule
check_prometheus_rule() {
    section "Validating Grafana PrometheusRule"

    local rule_file="$ROOT_DIR/manifests/grafana-prometheusRule.yaml"

    if [ ! -f "$rule_file" ]; then
        fail "Grafana PrometheusRule not found: $rule_file"
        return 1
    fi
    pass "Grafana PrometheusRule manifest exists"

    # Validate YAML syntax
    if command -v yamllint &> /dev/null; then
        if yamllint -d relaxed "$rule_file" &> /dev/null; then
            pass "PrometheusRule YAML syntax is valid"
        else
            fail "PrometheusRule YAML syntax errors detected"
        fi
    else
        info "yamllint not installed, skipping YAML validation"
    fi

    # Check for GrafanaRequestsFailing alert
    if grep -q "GrafanaRequestsFailing" "$rule_file"; then
        pass "GrafanaRequestsFailing alert found"
    else
        fail "GrafanaRequestsFailing alert not found"
    fi

    # Check for recording rules
    if grep -q "namespace_job_handler_statuscode:grafana_http_request_duration_seconds_count:rate5m" "$rule_file"; then
        pass "Grafana recording rule found"
    else
        fail "Grafana recording rule not found"
    fi

    # Check for runbook URL
    if grep -q "runbook_url:" "$rule_file"; then
        pass "Runbook URL found in alerts"
    else
        warn "No runbook URL found in alerts"
    fi

    # Validate Prometheus rule expressions (if promtool available)
    if command -v promtool &> /dev/null; then
        if promtool check rules "$rule_file" &> /dev/null; then
            pass "PrometheusRule expressions are valid (promtool check)"
        else
            fail "PrometheusRule expression validation failed"
            promtool check rules "$rule_file" || true
        fi
    else
        info "promtool not installed, skipping expression validation"
    fi
}

# Validate generated ServiceMonitor
check_service_monitor() {
    section "Validating Grafana ServiceMonitor"

    local sm_file="$ROOT_DIR/manifests/grafana-serviceMonitor.yaml"

    if [ ! -f "$sm_file" ]; then
        fail "Grafana ServiceMonitor not found: $sm_file"
        return 1
    fi
    pass "Grafana ServiceMonitor manifest exists"

    # Check for correct endpoint port
    if grep -q "port: http" "$sm_file"; then
        pass "ServiceMonitor scrapes 'http' port"
    else
        fail "ServiceMonitor not configured to scrape 'http' port"
    fi

    # Check for scrape interval
    if grep -q "interval:" "$sm_file"; then
        local interval=$(grep "interval:" "$sm_file" | head -1 | awk '{print $2}')
        pass "Scrape interval configured: $interval"
    else
        warn "No scrape interval specified (will use Prometheus default)"
    fi

    # Check for proper label selector
    if grep -q "app.kubernetes.io/name: grafana" "$sm_file"; then
        pass "ServiceMonitor has correct label selector"
    else
        fail "ServiceMonitor label selector incorrect or missing"
    fi
}

# Validate Grafana dashboard
check_dashboard() {
    section "Validating Grafana Dashboard"

    local dashboard_file="$ROOT_DIR/manifests/grafana-dashboardDefinitions.yaml"

    if [ ! -f "$dashboard_file" ]; then
        fail "Grafana dashboard definitions not found: $dashboard_file"
        return 1
    fi
    pass "Grafana dashboard definitions manifest exists"

    # Check for Grafana overview dashboard
    if grep -q "grafana-overview.json" "$dashboard_file"; then
        pass "Grafana Overview dashboard found"
    else
        fail "Grafana Overview dashboard not found"
    fi

    # Check for Grafana metrics in dashboard
    if grep -q "grafana_http_request_duration_seconds" "$dashboard_file"; then
        pass "Dashboard includes Grafana HTTP request metrics"
    else
        warn "Dashboard may not include Grafana HTTP metrics"
    fi

    if grep -q "grafana_build_info" "$dashboard_file"; then
        pass "Dashboard includes Grafana build info"
    else
        warn "Dashboard may not include Grafana build info"
    fi
}

# Check main.libsonnet integration
check_main_integration() {
    section "Validating Main Integration"

    local main_file="$ROOT_DIR/jsonnet/kube-prometheus/main.libsonnet"

    if [ ! -f "$main_file" ]; then
        fail "main.libsonnet not found"
        return 1
    fi
    pass "main.libsonnet exists"

    # Check that grafana component is imported
    if grep -q "import './components/grafana.libsonnet'" "$main_file"; then
        pass "Grafana component is imported in main.libsonnet"
    else
        fail "Grafana component import not found in main.libsonnet"
    fi

    # Check that grafana is instantiated
    if grep -q "grafana: grafana(.*values.grafana.*)" "$main_file"; then
        pass "Grafana component is instantiated"
    else
        fail "Grafana component instantiation not found"
    fi
}

# Validate example.jsonnet includes Grafana
check_example() {
    section "Validating Example Configuration"

    local example_file="$ROOT_DIR/example.jsonnet"

    if [ ! -f "$example_file" ]; then
        warn "example.jsonnet not found"
        return 0
    fi
    pass "example.jsonnet exists"

    # Check that Grafana manifests are generated
    if grep -q "grafana-" "$example_file"; then
        pass "Example generates Grafana manifests"
    else
        info "Example may use default Grafana configuration"
    fi
}

# Validate Kubernetes manifests
check_kubernetes_manifests() {
    section "Validating Kubernetes Resource Manifests"

    # Check if kubeconform is available
    if ! command -v kubeconform &> /dev/null; then
        info "kubeconform not installed, skipping Kubernetes schema validation"
        info "Install from: https://github.com/yannh/kubeconform"
        return 0
    fi

    local rule_file="$ROOT_DIR/manifests/grafana-prometheusRule.yaml"
    local sm_file="$ROOT_DIR/manifests/grafana-serviceMonitor.yaml"

    # Validate PrometheusRule against CRD schema
    if [ -f "$rule_file" ]; then
        if kubeconform -summary "$rule_file" 2>&1 | grep -q "^Valid:"; then
            pass "PrometheusRule is valid Kubernetes resource"
        else
            warn "PrometheusRule validation failed (may need CRD schemas)"
        fi
    fi

    # Validate ServiceMonitor against CRD schema
    if [ -f "$sm_file" ]; then
        if kubeconform -summary "$sm_file" 2>&1 | grep -q "^Valid:"; then
            pass "ServiceMonitor is valid Kubernetes resource"
        else
            warn "ServiceMonitor validation failed (may need CRD schemas)"
        fi
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    echo "Validation Summary"
    echo "========================================"
    echo -e "${GREEN}Passed:${NC} $PASS_COUNT"
    echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT"
    echo -e "${RED}Failed:${NC} $FAIL_COUNT"
    echo ""

    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}✓ All critical validations passed!${NC}"
        if [ $WARN_COUNT -gt 0 ]; then
            echo -e "${YELLOW}⚠ Some warnings were detected. Review the output above.${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ Some validations failed. Review the output above.${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "Grafana Monitoring Validation"
    echo "========================================"
    echo "Root directory: $ROOT_DIR"
    echo ""

    # Run all checks
    check_manifests_exist || true
    check_grafana_component || true
    check_dependencies || true
    check_prometheus_rule || true
    check_service_monitor || true
    check_dashboard || true
    check_main_integration || true
    check_example || true
    check_kubernetes_manifests || true

    # Print summary and exit with appropriate code
    print_summary
}

# Run main function
main "$@"
