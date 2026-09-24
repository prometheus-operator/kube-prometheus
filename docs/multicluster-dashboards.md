---
weight: 660
toc: true
title: Multi-cluster dashboard support
menu:
    docs:
        parent: kube
lead: Enable multi-cluster dashboard support in grafana
---

#Prerequisites

Let's say we have two clusters, `east` and `west`.

Each prometheus cluster should have `externalLabels` configured:

```jsonnet
# east
values+:: {
  prometheus+: {
    externalLabels: {
      cluster: "east",
    },
  },
}

# west
values+:: {
  prometheus+: {
    externalLabels: {
      cluster: "west",
    },
  },
}
```

# Enable multi cluster support

At the time of writing, only kubernetes-mixin and node-mixin support this.

```jsonnet
values+:: {
  nodeExporter+: {
    mixin+: {
      _config+: {
        showMultiCluster: true,
        # clusterLabel: '<cluster label, if different than the default "cluster">',
      },
    },
  },  
  kubernetesControlPlane+: {
    mixin+: {
      _config+: {
        showMultiCluster: true,
        # clusterLabel: '<cluster label, if different than the default "cluster">',
      },
    },
  },
}
```
