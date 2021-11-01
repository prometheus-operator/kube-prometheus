#!/bin/bash

DIR="crdschemas"

# Go to git repository root
cd ./$(git rev-parse --show-cdup)

rm -rf "$DIR"
mkdir "$DIR"

for crd in vendor/prometheus-operator/*-crd.json; do
	jq '.spec.versions[0].schema.openAPIV3Schema' < "$crd" > "$DIR/$(basename "$crd" | sed 's/s-crd//;s/prometheuse/prometheus/')"
done
