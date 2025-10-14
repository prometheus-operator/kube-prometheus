# Ephemeral developer workspaces

Aiming to provide better developer experience when making contributions to kube-prometheus, whether by actively developing new features/bug fixes or by reviewing pull requests, we want to provide ephemeral developer workspaces with everything already configured (as far as tooling makes it possible).

A developer workspace provides a brand new Kubernetes cluster, where kube-prometheus can be easily deployed and the contributor can easily see the impact that a pull request is proposing.

Today only [Github Codespaces](https://github.com/features/codespaces) is supported. Unfortunately, Codespaces is not available for everyone. If you are fortunate to have access to it, you can open a new workspace from a specific branch, or even from Pull Requests.

![image](https://user-images.githubusercontent.com/24193764/135522435-44b177b4-00d4-4863-b45b-2db47c8c70d0.png)

![image](https://user-images.githubusercontent.com/24193764/135522560-c64968ab-3b4e-4639-893a-c4d0a14421aa.png)

After your workspace start, you can deploy a kube-prometheus inside a Kind cluster inside by running `make deploy`.

If you are reviewing a PR, you'll have a fully-functional kubernetes cluster, generating real monitoring data that can be used to review if the proposed changes works as described.

If you are working on new features/bug fixes, you can regenerate kube-prometheus's YAML manifests with `make generate` and deploy it again with `make deploy`.
