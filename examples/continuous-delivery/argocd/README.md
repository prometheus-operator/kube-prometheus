## ArgoCD Example

This is the simplest, working example of an argocd app, the JSON object built is now an array of objects as that is the prefered format for ArgoCD. And ArgoCD specific annotations are added to manifests.

Requirements:

- **ArgoCD 1.7+**

- Follow the vendor generation steps at the root of this repository and generate a `vendored` folder (referenced in `application.yaml`).

- Make sure that argocd-cm has `application.instanceLabelKey` set to something else than `app.kubernetes.io/instance`, otherwise it will cause problems with prometheus target discovery. (see also [Why Is My App Out Of Sync Even After Syncing?](https://argo-cd.readthedocs.io/en/stable/faq/#why-is-my-app-out-of-sync-even-after-syncing))
