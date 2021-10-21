# Ephemeral developer workspaces

Aiming to provide better developer experience when making contributions to kube-prometheus, whether by actively developing new features/bug fixes or by reviewing pull requests, we want to provide ephemeral developer workspaces with everything already configured (as far as tooling makes it possible).

Those developer workspaces should provide a brand new kubernetes cluster, where kube-prometheus can be easily deployed and the contributor can easily see the impact that a pull request is proposing.

Today there is 2 providers in the market:
* [Github Codespaces](https://github.com/features/codespaces)
* [Gitpod](https://www.gitpod.io/)

## Codespaces

Unfortunately, Codespaces is not available for everyone. If you are fortunate to have access to it, you can open a new workspace from a specific branch, or even from Pull Requests.

![image](https://user-images.githubusercontent.com/24193764/135522435-44b177b4-00d4-4863-b45b-2db47c8c70d0.png)

![image](https://user-images.githubusercontent.com/24193764/135522560-c64968ab-3b4e-4639-893a-c4d0a14421aa.png)

After your workspace start, you can deploy a kube-prometheus inside a Kind cluster inside by running `make deploy`.

If you are reviewing a PR, you'll have a fully-functional kubernetes cluster, generating real monitoring data that can be used to review if the proposed changes works as described.

If you are working on new features/bug fixes, you can regenerate kube-prometheus's YAML manifests with `make generate` and deploy it again with `make deploy`.

## Gitpod

Gitpod is already available to everyone to use for free. It can also run commands that we speficy in the `.gitpod.yml` file located in the root directory of the git repository, so even the cluster creation can be fully automated.

You can use the same workflow as mentioned in the [Codespaces](#codespaces) section, however Gitpod doesn't have native support for any kubernetes distribution. The workaround is to create a full QEMU Virtual Machine and deploy [k3s](https://github.com/k3s-io/k3s) inside this VM. Don't worry, this whole process is already fully automated, but due to the workaround the whole workspace may be very slow.

To open up a workspace with Gitpod, you can install the [Google Chrome extension](https://www.gitpod.io/docs/browser-extension/) to add a new button to Github UI and use it on PRs or from the main page. Or by directly typing in the browser `http://gitpod.io/#https://github.com/prometheus-operator/kube-prometheus/pull/<Pull Request Number>` or just `http://gitpod.io/#https://github.com/prometheus-operator/kube-prometheus`

![image](https://user-images.githubusercontent.com/24193764/135534546-4f6bf0e5-57cd-4e35-ad80-88bd47d64276.png)
