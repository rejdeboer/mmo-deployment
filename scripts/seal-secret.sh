#!/bin/bash

CONTROLLER_NS="sealed-secrets"

set -e # Exit immediately if a command exits with a non-zero status.

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <secret-name> <secret-namespace> <key1=value1> [key2=value2] ..."
    echo "Example: $0 my-db-secret default username admin"
    exit 1
fi

SECRET_NAME="$1"
SECRET_NAMESPACE="$2"
shift 2

if ! command -v kubeseal &> /dev/null; then
    echo "Error: kubeseal command not found. Please install it."
    exit 1
fi

from_literal_args=()
for arg in "$@"; do
  from_literal_args+=(--from-literal="$arg")
done

kubectl create secret generic "${SECRET_NAME}" \
  --namespace="${SECRET_NAMESPACE}" \
  "${from_literal_args[@]}" \
  --dry-run=client -o yaml | \
kubeseal --controller-name sealed-secrets-sealed-secrets \
         --controller-namespace="${CONTROLLER_NS}" \
         --format=yaml

