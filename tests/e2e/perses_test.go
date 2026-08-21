// Copyright 2026 The prometheus-operator Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package e2e

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

const (
	persesNamespace           = "monitoring"
	minPersesDashboardObjects = 23
	persesAvailableCondition  = "Available"
	persesDegradedCondition   = "Degraded"
	operatorManagerContainer  = "manager"
)

func TestPersesAddon(t *testing.T) {
	if os.Getenv("PERESES_ADDON") != "true" {
		t.Skip("PERESES_ADDON != true, skipping perses addon tests")
	}

	kClient := promClient.kubeClient

	t.Run("grafana is not deployed", func(t *testing.T) {
		_, err := kClient.AppsV1().Deployments(persesNamespace).Get(context.Background(), "grafana", metav1.GetOptions{})
		if err == nil {
			t.Fatal("grafana deployment should not exist when using perses")
		}
		if !apierrors.IsNotFound(err) {
			t.Fatalf("unexpected error checking grafana deployment: %v", err)
		}

		_, err = kClient.CoreV1().Services(persesNamespace).Get(context.Background(), "grafana", metav1.GetOptions{})
		if err == nil {
			t.Fatal("grafana service should not exist when using perses")
		}
		if !apierrors.IsNotFound(err) {
			t.Fatalf("unexpected error checking grafana service: %v", err)
		}

		pods, err := kClient.CoreV1().Pods(persesNamespace).List(context.Background(), metav1.ListOptions{
			LabelSelector: "app.kubernetes.io/name=grafana",
		})
		if err != nil {
			t.Fatal(err)
		}
		if len(pods.Items) > 0 {
			t.Fatalf("expected no grafana pods, got %d", len(pods.Items))
		}
	})

	t.Run("operator deployment is ready", func(t *testing.T) {
		err := pollCondition(5*time.Minute, func() error {
			deploy, err := kClient.AppsV1().Deployments(persesNamespace).Get(context.Background(), "perses-operator", metav1.GetOptions{})
			if err != nil {
				return err
			}
			if deploy.Status.ReadyReplicas != *deploy.Spec.Replicas {
				return fmt.Errorf("expecting %d ready replicas, got %d", *deploy.Spec.Replicas, deploy.Status.ReadyReplicas)
			}
			return nil
		})
		if err != nil {
			t.Fatal(err)
		}
	})

	t.Run("perses instance is ready", func(t *testing.T) {
		err := pollCondition(5*time.Minute, func() error {
			return persesInstanceReady(kClient)
		})
		if err != nil {
			t.Fatal(formatPersesOperatorDebug(kClient, err))
		}
	})

	t.Run("perses CR status is available and not degraded", func(t *testing.T) {
		err := pollCondition(5*time.Minute, func() error {
			conditions, err := getPersesCRConditions(kClient)
			if err != nil {
				return err
			}
			return assertReconciledConditions(conditions, "Perses/perses")
		})
		if err != nil {
			t.Fatal(formatPersesOperatorDebug(kClient, err))
		}
	})

	t.Run("perses service responds", func(t *testing.T) {
		err := pollCondition(5*time.Minute, func() error {
			if err := persesServiceEndpointsReady(kClient); err != nil {
				return err
			}

			_, err := kClient.CoreV1().RESTClient().Get().
				Namespace(persesNamespace).
				Resource("services").
				Name("perses:http").
				SubResource("proxy").
				Suffix("/api/v1/health").
				DoRaw(context.Background())
			return err
		})
		if err != nil {
			t.Fatal(err)
		}
	})

	t.Run("dashboards and datasource CRs exist", func(t *testing.T) {
		err := pollCondition(5*time.Minute, func() error {
			dashboards, err := listPersesDashboardsWithStatus(kClient)
			if err != nil {
				return err
			}
			if len(dashboards) < minPersesDashboardObjects {
				return fmt.Errorf("expected at least %d PersesDashboard objects, got %d", minPersesDashboardObjects, len(dashboards))
			}

			for _, dashboard := range dashboards {
				if err := assertReconciledConditions(dashboard.Conditions, "PersesDashboard/"+dashboard.Name); err != nil {
					return err
				}
			}

			_, err = kClient.CoreV1().RESTClient().Get().
				AbsPath("/apis/perses.dev/v1alpha2/persesglobaldatasources/prometheus-datasource").
				DoRaw(context.Background())
			return err
		})
		if err != nil {
			t.Fatal(formatPersesOperatorDebug(kClient, err))
		}
	})

	t.Run("operator scraped by prometheus", func(t *testing.T) {
		err := pollCondition(5*time.Minute, func() error {
			n, err := promClient.query(`up{job="perses-operator"} == 1`)
			if err != nil {
				return err
			}
			if n < 1 {
				return fmt.Errorf("expected at least 1 up target for job=perses-operator, got %d", n)
			}
			return nil
		})
		if err != nil {
			t.Fatal(err)
		}
	})
}

func persesInstanceReady(kClient kubernetes.Interface) error {
	statefulSet, err := kClient.AppsV1().StatefulSets(persesNamespace).Get(context.Background(), "perses", metav1.GetOptions{})
	if err == nil {
		if statefulSet.Status.ReadyReplicas < 1 {
			return fmt.Errorf("expecting at least 1 ready perses replica, got %d", statefulSet.Status.ReadyReplicas)
		}
		return nil
	}

	deploy, err := kClient.AppsV1().Deployments(persesNamespace).Get(context.Background(), "perses", metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("perses workload not found: %w", err)
	}
	if deploy.Status.ReadyReplicas != *deploy.Spec.Replicas {
		return fmt.Errorf("expecting %d ready perses replicas, got %d", *deploy.Spec.Replicas, deploy.Status.ReadyReplicas)
	}
	return nil
}

func persesServiceEndpointsReady(kClient kubernetes.Interface) error {
	endpoints, err := kClient.CoreV1().Endpoints(persesNamespace).Get(context.Background(), "perses", metav1.GetOptions{})
	if err != nil {
		return err
	}

	for _, subset := range endpoints.Subsets {
		if len(subset.Addresses) > 0 {
			return nil
		}
	}

	return fmt.Errorf("perses service has no ready endpoints")
}

func listPersesDashboardsWithStatus(kClient kubernetes.Interface) ([]persesDashboardItem, error) {
	raw, err := kClient.CoreV1().RESTClient().Get().
		AbsPath("/apis/perses.dev/v1alpha2/namespaces", persesNamespace, "persesdashboards").
		DoRaw(context.Background())
	if err != nil {
		return nil, err
	}

	var list struct {
		Items []struct {
			Metadata struct {
				Name string `json:"name"`
			} `json:"metadata"`
			Status struct {
				Conditions []metav1.Condition `json:"conditions"`
			} `json:"status"`
		} `json:"items"`
	}
	if err := json.Unmarshal(raw, &list); err != nil {
		return nil, err
	}

	dashboards := make([]persesDashboardItem, 0, len(list.Items))
	for _, item := range list.Items {
		dashboards = append(dashboards, persesDashboardItem{
			Name:       item.Metadata.Name,
			Conditions: item.Status.Conditions,
		})
	}

	return dashboards, nil
}

type persesDashboardItem struct {
	Name       string
	Conditions []metav1.Condition
}

func getPersesCRConditions(kClient kubernetes.Interface) ([]metav1.Condition, error) {
	raw, err := kClient.CoreV1().RESTClient().Get().
		AbsPath("/apis/perses.dev/v1alpha2/namespaces", persesNamespace, "perses", "perses").
		DoRaw(context.Background())
	if err != nil {
		return nil, err
	}

	var perses struct {
		Status struct {
			Conditions []metav1.Condition `json:"conditions"`
		} `json:"status"`
	}
	if err := json.Unmarshal(raw, &perses); err != nil {
		return nil, err
	}

	return perses.Status.Conditions, nil
}

func getCondition(conditions []metav1.Condition, conditionType string) (metav1.Condition, bool) {
	for _, condition := range conditions {
		if condition.Type == conditionType {
			return condition, true
		}
	}
	return metav1.Condition{}, false
}

func assertReconciledConditions(conditions []metav1.Condition, resourceName string) error {
	available, ok := getCondition(conditions, persesAvailableCondition)
	if !ok || available.Status != metav1.ConditionTrue {
		detail := "condition not set"
		if ok {
			detail = fmt.Sprintf("reason=%s message=%s", available.Reason, available.Message)
		}
		return fmt.Errorf("%s: Available!=True (%s)", resourceName, detail)
	}

	degraded, ok := getCondition(conditions, persesDegradedCondition)
	if !ok {
		return fmt.Errorf("%s: Degraded condition not set", resourceName)
	}
	if degraded.Status == metav1.ConditionTrue {
		return fmt.Errorf("%s: Degraded=True reason=%s message=%s", resourceName, degraded.Reason, degraded.Message)
	}
	if degraded.Status != metav1.ConditionFalse {
		return fmt.Errorf("%s: Degraded=%s reason=%s message=%s", resourceName, degraded.Status, degraded.Reason, degraded.Message)
	}

	return nil
}

func getOperatorManagerLogs(kClient kubernetes.Interface, tailLines int64) (string, error) {
	pods, err := kClient.CoreV1().Pods(persesNamespace).List(context.Background(), metav1.ListOptions{
		LabelSelector: "app.kubernetes.io/name=perses-operator",
	})
	if err != nil {
		return "", err
	}
	if len(pods.Items) == 0 {
		return "", fmt.Errorf("perses-operator pod not found")
	}

	tail := tailLines
	req := kClient.CoreV1().Pods(persesNamespace).GetLogs(pods.Items[0].Name, &corev1.PodLogOptions{
		Container: operatorManagerContainer,
		TailLines: &tail,
	})
	logBytes, err := req.DoRaw(context.Background())
	if err != nil {
		return "", err
	}

	return string(logBytes), nil
}

func formatPersesOperatorDebug(kClient kubernetes.Interface, err error) error {
	logs, logErr := getOperatorManagerLogs(kClient, 200)
	if logErr != nil {
		return fmt.Errorf("%w\n\nfailed to fetch perses-operator logs: %v", err, logErr)
	}

	return fmt.Errorf("%w\n\nrecent perses-operator manager logs:\n%s", err, logs)
}
