#!/bin/bash

# A script to standardize the creation of Sealed Secrets.

CONTROLLER_NS="flux-system"

set -e # Exit immediately if a command exits with a non-zero status.

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <secret-name> <secret-namespace> <key-name> <value>"
    echo "Example: $0 my-db-secret default username admin"
    exit 1
fi

SECRET_NAME="$1"
SECRET_NAMESPACE="$2"
KEY_NAME="$3"
VALUE="$4"

if ! command -v kubeseal &> /dev/null; then
    echo "Error: kubeseal command not found. Please install it."
    exit 1
fi

echo "Sealing secret '$SECRET_NAME' in namespace '$SECRET_NAMESPACE'..."

kubectl create secret generic "${SECRET_NAME}" \
  --namespace="${SECRET_NAMESPACE}" \
  --from-literal="${KEY_NAME}=${VALUE}" \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace="${CONTROLLER_NS}" \
         --format=yaml

echo -e "\n✅ Success! Pipe the output above into a YAML file in your Git repository."
echo "   Example: ./scripts/seal-secret.sh ... > ./clusters/main/apps/my-app/secret.yaml"
