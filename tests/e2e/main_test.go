// Copyright 2019 The prometheus-operator Authors
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
	"log"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Jeffail/gabs"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

var promClient *prometheusClient

func TestMain(m *testing.M) {
	os.Exit(testMain(m))
}

// testMain circumvents the issue, that one can not call `defer` in TestMain, as
// `os.Exit` does not honor `defer` statements. For more details see:
// http://blog.englund.nu/golang,/testing/2017/03/12/using-defer-in-testmain.html
func testMain(m *testing.M) int {
	kubeConfigPath, ok := os.LookupEnv("KUBECONFIG")
	if !ok {
		log.Fatal("failed to retrieve KUBECONFIG env var")
	}

	config, err := clientcmd.BuildConfigFromFlags("", kubeConfigPath)
	if err != nil {
		log.Fatal(err)
	}

	kubeClient, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatal(fmt.Errorf("creating kubeClient failed: %w", err))
	}

	promClient = newPrometheusClient(kubeClient)

	return m.Run()
}

func pollCondition(timeout time.Duration, conditionFunc func() error) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	var conditionErr error
	if err := wait.PollImmediateUntilWithContext(ctx, 5*time.Second, func(context.Context) (bool, error) {
		conditionErr = conditionFunc()
		return conditionErr == nil, nil
	}); err != nil {
		return fmt.Errorf("%w: %w", err, conditionErr)
	}

	return nil
}

func TestQueryPrometheus(t *testing.T) {
	// Wait for pod to respond at queries at all. Then start verifying their results.
	err := pollCondition(1*time.Minute, func() error {
		_, err := promClient.query("up")
		return err
	})
	if err != nil {
		t.Fatal(fmt.Errorf("wait for prometheus-k8s: %w", err))
	}

	for _, tc := range []struct {
		job     string
		expectN int
	}{
		{
			job:     "node-exporter",
			expectN: 1,
		}, {
			job:     "apiserver",
			expectN: 1,
		}, {
			// There are 4 kubelet endpoints.
			job:     "kubelet",
			expectN: 4,
		}, {
			job:     "kube-scheduler",
			expectN: 1,
		}, {
			job:     "kube-controller-manager",
			expectN: 1,
		}, {
			job:     "kube-state-metrics",
			expectN: 1,
		}, {
			job:     "prometheus-k8s",
			expectN: 1,
		}, {
			job:     "prometheus-operator",
			expectN: 1,
		}, {
			job:     "alertmanager-main",
			expectN: 2,
		},
	} {
		t.Run(tc.job, func(t *testing.T) {
			err = pollCondition(1*time.Minute, func() error {
				n, err := promClient.query(fmt.Sprintf(`up{job="%s"} == 1`, tc.job))
				if err != nil {
					return err
				}

				if n < tc.expectN {
					// Don't return an error as targets may only become visible after a while.
					return fmt.Errorf("expected at least %d results for job=%q but got %d", tc.expectN, tc.job, n)
				}

				return nil
			})
			if err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestDroppedMetrics(t *testing.T) {
	t.Parallel()
	// query metadata for all metrics and their metadata
	md, err := promClient.metadata("{job=~\".+\"}")
	if err != nil {
		t.Fatal(err)
	}
	for _, k := range md {
		// check if the metric' help text contains Deprecated
		if strings.Contains(k.Help, "Deprecated") {
			// query prometheus for the Deprecated metric
			n, err := promClient.query(k.Metric)
			if err != nil {
				t.Fatal(err)
			}
			if n > 0 {
				t.Fatalf("deprecated metric with name: %s and help text: %s exists.", k.Metric, k.Help)
			}
		}
	}
}

func TestTargetsScheme(t *testing.T) {
	t.Parallel()
	// query targets for all endpoints
	tgs, err := promClient.targets()
	if err != nil {
		t.Fatal(err)
	}

	// exclude jobs from checking for http endpoints
	// TODO(paulfantom): This should be reduced as we secure connections for those components
	exclude := map[string]bool{
		"alertmanager-main": true,
		"prometheus-k8s":    true,
		"kube-dns":          true,
		"grafana":           true,
	}

	for _, k := range tgs.Active {
		job := k.Labels["job"]
		if k.DiscoveredLabels["__scheme__"] == "http" && !exclude[string(job)] {
			t.Fatalf("target exposing metrics over HTTP instead of HTTPS: %+v", k)
		}
	}
}

// TestFailedRuleEvaluations detects recording and alerting rules that may
// trigger "many-to-many" evaluation errors when multiple kube-state-metrics
// instances are running.
func TestFailedRuleEvaluations(t *testing.T) {
	t.Parallel()
	// Scale kube-state-metrics to 2 replicas.
	kClient := promClient.kubeClient

	scale, err := kClient.AppsV1().Deployments("monitoring").GetScale(context.Background(), "kube-state-metrics", metav1.GetOptions{})
	if err != nil {
		t.Fatal(err)
	}

	scale.Spec.Replicas = 2
	scale, err = kClient.AppsV1().Deployments("monitoring").UpdateScale(context.Background(), "kube-state-metrics", scale, metav1.UpdateOptions{})
	if err != nil {
		t.Fatal(err)
	}

	// Rollback to 1 replica at the end of the test.
	defer func() {
		scale, err := kClient.AppsV1().Deployments("monitoring").GetScale(context.Background(), "kube-state-metrics", metav1.GetOptions{})
		if err != nil {
			t.Fatal(err)
		}

		scale.Spec.Replicas = 1
		_, err = kClient.AppsV1().Deployments("monitoring").UpdateScale(context.Background(), "kube-state-metrics", scale, metav1.UpdateOptions{})
		if err != nil {
			t.Fatal(err)
		}
	}()

	// Wait for the 2 replicas of kube-state-metrics to be successfully scraped.
	err = pollCondition(2*time.Minute, func() error {
		n, err := promClient.query(`up{job="kube-state-metrics"} == 1`)
		if err != nil {
			return err
		}

		if n != 2 {
			return fmt.Errorf("expecting 2 kube-state-metrics targets, got %d", n)
		}

		return nil
	})
	if err != nil {
		t.Fatalf("waiting for kube-state-metrics: %s", err)
	}

	// Wait for all rule groups to be evaluated at least once without error.
	now := time.Now()
	err = pollCondition(5*time.Minute, func() error {
		rsp, err := promClient.apiRequest("/api/v1/rules", "type", "")
		if err != nil {
			return err
		}

		res, err := gabs.ParseJSON(rsp.Data)
		if err != nil {
			return err
		}

		groups, err := res.Path("groups").Children()
		if err != nil {
			return err
		}

		if len(groups) == 0 {
			return fmt.Errorf("got 0 rule groups")
		}

		for _, group := range groups {
			groupName := group.Path("name").Data().(string)
			if err != nil {
				return err
			}

			lastEvalString := group.Path("lastEvaluation").Data().(string)
			lastEval, err := time.Parse(time.RFC3339Nano, lastEvalString)
			if err != nil {
				return err
			}

			if lastEval.Before(now) {
				return fmt.Errorf("%s not yet evaluated", groupName)
			}

			rules, err := group.Path("rules").Children()
			if err != nil {
				return err
			}

			if len(rules) == 0 {
				return fmt.Errorf("got 0 rules in group %s", groupName)
			}

			for _, rule := range rules {
				health := rule.Path("health").Data().(string)
				if health != "ok" {
					return fmt.Errorf("error evaluating rule: %v", rule)
				}
			}
		}

		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestGrafana(t *testing.T) {
	t.Parallel()
	kClient := promClient.kubeClient

	err := pollCondition(5*time.Minute, func() error {
		grafanaDeployment, err := kClient.AppsV1().Deployments("monitoring").Get(context.Background(), "grafana", metav1.GetOptions{})
		if err != nil {
			return err
		}

		if grafanaDeployment.Status.ReadyReplicas != *grafanaDeployment.Spec.Replicas {
			return fmt.Errorf("expecting %d replicas, got %d", *grafanaDeployment.Spec.Replicas, grafanaDeployment.Status.ReadyReplicas)
		}

		return nil
	})
	if err != nil {
		t.Fatal(fmt.Errorf("timeout while waiting for Grafana deployment ready condition: %w", err))
	}
}
