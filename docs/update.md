# Update kube-prometheus

You may wish to fetch changes made on this project so they are available to you.

## Update jb

`jb` may have been updated so it's a good idea to get the latest version of this binary:

```shell
$ go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
```

## Update kube-prometheus

The command below will sync with upstream project:

```shell
$ jb update
```

## Compile the manifests and apply

Once updated, just follow the instructions under [Generating](customizing.md#generating) and [Apply the kube-prometheus stack](customizing.md#apply-the-kube-prometheus-stack) from [customizing.md doc](customizing.md) to apply the changes to your cluster.

## Migration from previous versions

If you are migrating from `release-0.7` branch or earlier please read [what changed and how to migrate in our guide](https://github.com/prometheus-operator/kube-prometheus/blob/main/docs/migration-guide.md).

Refer to [migration document](migration-example) for more information about migration from 0.3 and 0.8 versions of kube-prometheus.
