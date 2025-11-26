#!/bin/bash

if ! curl -s --output /dev/null --connect-timeout 2 "$VAULT_ADDR/v1/sys/health"; then
    echo "❌ Vault is unreachable at $VAULT_ADDR"
    exit 1
fi

INIT_STATUS=$(curl -s "$VAULT_ADDR/v1/sys/init" | jq -r .initialized)

if [ "$INIT_STATUS" == "true" ]; then
    echo "✅ Vault is already initialized."
else
    echo "⚙️ Initializing Vault..."
    vault operator init \
        -address="$VAULT_ADDR" \
        -key-shares=1 \
        -key-threshold=1 \
        -format=json > $KEY_FILE

    echo "✅ Vault Initialized! Keys saved to $KEY_FILE"
fi
