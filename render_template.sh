#!/bin/bash

# Check if the input file is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_helmrelease_yaml>"
    exit 1
fi

HELM_RELEASE_FILE="$1"

# Create a temporary file for the values
VALUES_FILE=$(mktemp -p /tmp/values.XXXXXX.yaml)

# Extract values from the HelmRelease YAML file
yq eval -o yaml '.spec.values' "$HELM_RELEASE_FILE" > "$VALUES_FILE"

# Check if the extraction was successful
if [ $? -ne 0 ]; then
    echo "Failed to extract values."
    exit 1
fi

# Dynamically extract necessary values
RELEASE_NAME=$(yq eval '.metadata.name' "$HELM_RELEASE_FILE")
NAMESPACE=$(yq eval '.metadata.namespace' "$HELM_RELEASE_FILE")
CHART_NAME=$(yq eval '.spec.chart.spec.chart' "$HELM_RELEASE_FILE")
CHART_VERSION=$(yq eval '.spec.chart.spec.version' "$HELM_RELEASE_FILE")
REPO_NAME=$(yq eval '.spec.chart.spec.sourceRef.name' "$HELM_RELEASE_FILE")

# Run the helm template command
helm template "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" --version "$CHART_VERSION" -f "$VALUES_FILE" --namespace "$NAMESPACE"

# Check if the helm template command was successful
if [ $? -eq 0 ]; then
    echo "Helm template rendered successfully."
else
    echo "Failed to render helm template."
    exit 1
fi

# Optionally, you can remove the temporary file after use
rm "$VALUES_FILE"
