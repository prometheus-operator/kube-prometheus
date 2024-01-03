# Contributing

This project is licensed under the [Apache 2.0 license](LICENSE) and accept
contributions via GitHub pull requests. This document outlines some of the
conventions on development workflow, commit message formatting, contact points
and other resources to make it easier to get your contribution accepted.

To maintain a safe and welcoming community, all participants must adhere to the
project's [Code of Conduct](code-of-conduct.md).

## Community

The project is developed in the open. Here are some of the channels we use to communicate and contribute:

[**Kubernetes Slack**](https://slack.k8s.io/): [#prometheus-operator](https://kubernetes.slack.com/archives/CFFDS2Z7F) -
General discussions channel

[**Kubernetes Slack**](https://slack.k8s.io/): [#prometheus-operator-dev](https://kubernetes.slack.com/archives/C01B03QCSMN) -
Channel used for project developers discussions

**Discussion forum**: [GitHub discussions](https://github.com/prometheus-operator/kube-prometheus/discussions)

**Twitter**: [@PromOperator](https://twitter.com/PromOperator)

**GitHub**: To file bugs and feature requests. For questions and discussions use the GitHub discussions. Generally,
the other community channels listed here are best suited to get support or discuss overarching topics.

Please avoid emailing maintainers directly.

We host publicy bi-weekly meetings focused on project development and contributions. It’s meant for developers
and maintainers to meet and get unblocked, pair review, and discuss development aspects of this project and related
projects (e.g kubernetes-mixin). The document linked below contains all the details, including how to register.

**Office Hours**: [Prometheus Operator & Kube-prometheus Contributor Office Hours](https://docs.google.com/document/d/1-fjJmzrwRpKmSPHtXN5u6VZnn39M28KqyQGBEJsqUOk)

## Getting Started

- Fork the repository on GitHub
- Read the [README](README.md) for build and test instructions
- Play with the project, submit bug fixes, submit patches!

## Contribution Flow

This is a rough outline of what a contributor's workflow looks like:

- Create a topic branch from where you want to base your work (usually `main`).
- Make commits of logical units.
- Make sure your commit messages are in the proper format (see below).
- Push your changes to a topic branch in your fork of the repository.
- Make sure the tests pass, and add any new tests as appropriate.
- Submit a pull request to the original repository.

Thanks for your contributions!

### Generated Files

All `.yaml` files in the `/manifests` folder are generated via
[Jsonnet](https://jsonnet.org/). Contributing changes will most likely include
the following process:

1. Make your changes in the respective `*.jsonnet` or `*.libsonnet` file.
2. Commit your changes (This is currently necessary due to our vendoring
   process. This is likely to change in the future).
3. Generate dependent `*.yaml` files: `make generate`
4. Commit the generated changes.

### Format of the Commit Message

We follow a rough convention for commit messages that is designed to answer two
questions: what changed and why. The subject line should feature the what and
the body of the commit should describe the why.

```
scripts: add the test-cluster command

this uses tmux to setup a test cluster that you can easily kill and
start for debugging.

Fixes #38
```

The format can be described more formally as follows:

```
<subsystem>: <what changed>
<BLANK LINE>
<why this change was made>
<BLANK LINE>
<footer>
```

The first line is the subject and should be no longer than 70 characters, the
second line is always blank, and other lines should be wrapped at 80 characters.
This allows the message to be easier to read on GitHub as well as in various
git tools.
