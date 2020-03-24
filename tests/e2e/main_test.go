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
	"log"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/pkg/errors"
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
		log.Fatal(errors.Wrap(err, "creating kubeClient failed"))
	}

	promClient = newPrometheusClient(kubeClient)

	return m.Run()
}

func TestQueryPrometheus(t *testing.T) {
	queries := []struct {
		query   string
		expectN int
	}{
		{
			query:   `up{job="node-exporter"} == 1`,
			expectN: 1,
		}, {
			// 	query:   `up{job="kubelet"} == 1`,
			// 	expectN: 1,
			// }, {
			query:   `up{job="apiserver"} == 1`,
			expectN: 1,
		}, {
			query:   `up{job="kube-state-metrics"} == 1`,
			expectN: 1,
		}, {
			query:   `up{job="prometheus-k8s"} == 1`,
			expectN: 1,
		}, {
			query:   `up{job="prometheus-operator"} == 1`,
			expectN: 1,
		}, {
			query:   `up{job="alertmanager-main"} == 1`,
			expectN: 2,
		},
	}

	// Wait for pod to respond at queries at all. Then start verifying their results.
	err := wait.Poll(5*time.Second, 1*time.Minute, func() (bool, error) {
		_, err := promClient.query("up")
		return err == nil, nil
	})
	if err != nil {
		t.Fatal(errors.Wrap(err, "wait for prometheus-k8s"))
	}

	err = wait.Poll(5*time.Second, 1*time.Minute, func() (bool, error) {
		defer t.Log("---------------------------\n")

		for _, q := range queries {
			n, err := promClient.query(q.query)
			if err != nil {
				return false, err
			}
			if n < q.expectN {
				// Don't return an error as targets may only become visible after a while.
				t.Logf("expected at least %d results for %q but got %d", q.expectN, q.query, n)
				return false, nil
			}
			t.Logf("query %q succeeded", q.query)
		}
		return true, nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestDroppedMetrics(t *testing.T) {
	// query metadata for all metrics and their metadata
	md, err := promClient.metadata("{job=~\".+\"}")
	if err != nil {
		log.Fatal(err)
	}
	for _, k := range md {
		// check if the metric' help text contains Deprecated
		if strings.Contains(k.Help, "Deprecated") {
			// query prometheus for the Deprecated metric
			n, err := promClient.query(k.Metric)
			if err != nil {
				log.Fatal(err)
			}
			if n > 0 {
				t.Fatalf("deprecated metric with name: %s and help text: %s exists.", k.Metric, k.Help)
			}
		}

	}
}

func TestTargetsScheme(t *testing.T) {
	// query targets for all endpoints
	tgs, err := promClient.targets()
	if err != nil {
		log.Fatal(err)
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
			log.Fatalf("target exposing metrics over HTTP instead of HTTPS: %+v", k)
		}
	}
}
