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

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

const (
	persesNamespace           = "monitoring"
	minPersesDashboardObjects = 23
)

func TestPersesAddon(t *testing.T) {
	if os.Getenv("PERESES_ADDON") != "true" {
		t.Skip("PERESES_ADDON != true, skipping perses addon tests")
	}

	kClient := promClient.kubeClient

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
			t.Fatal(err)
		}
	})

	t.Run("perses service responds", func(t *testing.T) {
		err := pollCondition(5*time.Minute, func() error {
			_, err := kClient.CoreV1().RESTClient().Get().
				Namespace(persesNamespace).
				Resource("services").
				Name("perses").
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
			dashboards, err := listPersesDashboards(kClient)
			if err != nil {
				return err
			}
			if dashboards < minPersesDashboardObjects {
				return fmt.Errorf("expected at least %d PersesDashboard objects, got %d", minPersesDashboardObjects, dashboards)
			}

			_, err = kClient.CoreV1().RESTClient().Get().
				AbsPath("/apis/perses.dev/v1alpha2/persesglobaldatasources/prometheus-datasource").
				DoRaw(context.Background())
			return err
		})
		if err != nil {
			t.Fatal(err)
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

func listPersesDashboards(kClient kubernetes.Interface) (int, error) {
	raw, err := kClient.CoreV1().RESTClient().Get().
		AbsPath("/apis/perses.dev/v1alpha2/namespaces", persesNamespace, "persesdashboards").
		DoRaw(context.Background())
	if err != nil {
		return 0, err
	}

	var list struct {
		Items []json.RawMessage `json:"items"`
	}
	if err := json.Unmarshal(raw, &list); err != nil {
		return 0, err
	}

	return len(list.Items), nil
}
