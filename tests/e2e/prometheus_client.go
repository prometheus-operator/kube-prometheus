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
	"bytes"
	"context"
	"encoding/json"
	"fmt"

	"k8s.io/client-go/kubernetes"

	"github.com/Jeffail/gabs"
	promv1 "github.com/prometheus/client_golang/api/prometheus/v1"
)

type prometheusClient struct {
	kubeClient kubernetes.Interface
}

func newPrometheusClient(kubeClient kubernetes.Interface) *prometheusClient {
	return &prometheusClient{kubeClient}
}

// Response hold API response in a form similar to apiResponse struct from prometheus/client_golang
// https://github.com/prometheus/client_golang/blob/master/api/prometheus/v1/api.go
type Response struct {
	Status string          `json:"status"`
	Data   json.RawMessage `json:"data"`
}

// apiRequest makes a request against specified Prometheus API endpoint
func (c *prometheusClient) apiRequest(endpoint string, selector string, query string) (Response, error) {
	req := c.kubeClient.CoreV1().RESTClient().Get().
		Namespace("monitoring").
		Resource("pods").
		SubResource("proxy").
		Name("prometheus-k8s-0:9090").
		Suffix(endpoint).Param(selector, query)

	var data Response
	b, err := req.DoRaw(context.Background())
	if err != nil {
		return data, err
	}

	r := bytes.NewReader(b)
	decoder := json.NewDecoder(r)
	err = decoder.Decode(&data)
	if err != nil {
		return data, err
	}

	if data.Status != "success" {
		return data, fmt.Errorf("status of returned response was not successful; status: %s", data.Status)
	}

	return data, err
}

// Query makes a request against the Prometheus /api/v1/query endpoint.
func (c *prometheusClient) query(query string) (int, error) {
	req := c.kubeClient.CoreV1().RESTClient().Get().
		Namespace("monitoring").
		Resource("pods").
		SubResource("proxy").
		Name("prometheus-k8s-0:9090").
		Suffix("/api/v1/query").Param("query", query)

	b, err := req.DoRaw(context.Background())
	if err != nil {
		return 0, err
	}

	res, err := gabs.ParseJSON(b)
	if err != nil {
		return 0, err
	}

	n, err := res.ArrayCountP("data.result")
	return n, err
}

// metadata makes a request against the Prometheus /api/v1/targets/metadata endpoint.
// It returns all the metrics and its metadata.
func (c *prometheusClient) metadata(query string) ([]promv1.MetricMetadata, error) {
	var metadata []promv1.MetricMetadata
	rsp, err := c.apiRequest("/api/v1/targets/metadata", "match_target", query)

	r := bytes.NewReader(rsp.Data)
	decoder := json.NewDecoder(r)
	err = decoder.Decode(&metadata)
	if err != nil {
		return metadata, err
	}
	return metadata, err
}

// targets makes a request against the Prometheus /api/v1/targets endpoint.
// It returns all targets registered in prometheus.
func (c *prometheusClient) targets() (promv1.TargetsResult, error) {
	var targets promv1.TargetsResult
	rsp, err := c.apiRequest("/api/v1/targets", "state", "any")
	if err != nil {
		return targets, err
	}

	r := bytes.NewReader(rsp.Data)
	decoder := json.NewDecoder(r)
	err = decoder.Decode(&targets)
	if err != nil {
		return targets, err
	}

	return targets, err
}
