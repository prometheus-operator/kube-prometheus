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
	"fmt"
	"os"
	"testing"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestMetricsServerDeployment(t *testing.T) {
	if os.Getenv("RESOURCE_METRICS_API") != "metrics-server" {
		t.Skip("RESOURCE_METRICS_API != metrics-server, skipping metrics-server tests")
	}

	kClient := promClient.kubeClient

	t.Run("deployment is ready", func(t *testing.T) {
		err := pollCondition(5*time.Minute, func() error {
			deploy, err := kClient.AppsV1().Deployments("monitoring").Get(context.Background(), "metrics-server", metav1.GetOptions{})
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

	t.Run("metrics API serves node and pod metrics", func(t *testing.T) {
		for _, path := range []string{
			"/apis/metrics.k8s.io/v1beta1/nodes",
			"/apis/metrics.k8s.io/v1beta1/namespaces/monitoring/pods",
		} {
			t.Run(path, func(t *testing.T) {
				err := pollCondition(5*time.Minute, func() error {
					_, err := kClient.Discovery().RESTClient().Get().AbsPath(path).DoRaw(context.Background())
					return err
				})
				if err != nil {
					t.Fatal(err)
				}
			})
		}
	})

	t.Run("scraped by prometheus", func(t *testing.T) {
		err := pollCondition(2*time.Minute, func() error {
			n, err := promClient.query(`up{job="metrics-server"} == 1`)
			if err != nil {
				return err
			}
			if n < 1 {
				return fmt.Errorf("expected at least 1 up target for job=metrics-server, got %d", n)
			}
			return nil
		})
		if err != nil {
			t.Fatal(err)
		}
	})
}
