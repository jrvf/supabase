#!/bin/sh

###############################################################################
# generate-env.sh
#
# Description:
#   Generates a new .env.coolify file based on .env.example, replacing all
#   secret values with newly generated secure values. Outputs the generated
#   secrets to stdout for reference.
#
# Usage:
#   ./generate-env.sh
#
# Requirements:
#   - openssl must be installed and available in PATH
#
# Output:
#   - .env.coolify file with updated secrets
#   - Prints generated secrets to stdout
###############################################################################

set -e

# --- Utility functions ---

gen_hex() {
    # Generate a random hex string of given byte length
    openssl rand -hex "$1"
}

gen_base64() {
    # Generate a random base64 string of given byte length
    openssl rand -base64 "$1"
}

base64_url_encode() {
    # Encode stdin to base64url (no padding, URL-safe)
    openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
}

gen_token() {
    # Generate a JWT token with given payload and global jwt_secret
    payload=$1
    payload_base64=$(printf %s "$payload" | base64_url_encode)
    header_base64=$(printf %s "$header" | base64_url_encode)
    signed_content="${header_base64}.${payload_base64}"
    signature=$(printf %s "$signed_content" | openssl dgst -binary -sha256 -hmac "$jwt_secret" | base64_url_encode)
    printf '%s' "${signed_content}.${signature}"
}

require_openssl() {
    # Ensure openssl is available
    if ! command -v openssl >/dev/null 2>&1; then
        echo "Error: openssl is required but not found."
        exit 1
    fi
}

generate_secrets() {
    # Generate all secrets and export as variables
    export jwt_secret="$(gen_base64 30)"

    header='{"alg":"HS256","typ":"JWT"}'
    iat=$(date +%s)
    exp=$((iat + 5 * 3600 * 24 * 365)) # 5 years

    anon_payload="{\"role\":\"anon\",\"iss\":\"supabase\",\"iat\":$iat,\"exp\":$exp}"
    service_role_payload="{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$iat,\"exp\":$exp}"

    export anon_key=$(gen_token "$anon_payload")
    export service_role_key=$(gen_token "$service_role_payload")

    export secret_key_base=$(gen_base64 48)
    export vault_enc_key=$(gen_hex 16)
    export pg_meta_crypto_key=$(gen_base64 24)

    export logflare_public_access_token=$(gen_base64 24)
    export logflare_private_access_token=$(gen_base64 24)

    export s3_protocol_access_key_id=$(gen_hex 16)
    export s3_protocol_access_key_secret=$(gen_hex 32)

    export postgres_password=$(gen_hex 16)
    export dashboard_password=$(gen_hex 16)
}

print_secrets() {
    # Print generated secrets to stdout
    echo ""
    echo "Generated secrets:"
    echo "JWT_SECRET=${jwt_secret}"
    echo "ANON_KEY=${anon_key}"
    echo "SERVICE_ROLE_KEY=${service_role_key}"
    echo "SECRET_KEY_BASE=${secret_key_base}"
    echo "VAULT_ENC_KEY=${vault_enc_key}"
    echo "PG_META_CRYPTO_KEY=${pg_meta_crypto_key}"
    echo "LOGFLARE_PUBLIC_ACCESS_TOKEN=${logflare_public_access_token}"
    echo "LOGFLARE_PRIVATE_ACCESS_TOKEN=${logflare_private_access_token}"
    echo "S3_PROTOCOL_ACCESS_KEY_ID=${s3_protocol_access_key_id}"
    echo "S3_PROTOCOL_ACCESS_KEY_SECRET=${s3_protocol_access_key_secret}"
    echo "POSTGRES_PASSWORD=${postgres_password}"
    echo "DASHBOARD_PASSWORD=${dashboard_password}"
    echo ""
}

replace_env_secrets() {
    # Replace secrets in ENV_EXAMPLE and write to ENV_COOLIFY
    sed \
        -e "s|^JWT_SECRET=.*$|JWT_SECRET=${jwt_secret}|" \
        -e "s|^ANON_KEY=.*$|ANON_KEY=${anon_key}|" \
        -e "s|^SERVICE_ROLE_KEY=.*$|SERVICE_ROLE_KEY=${service_role_key}|" \
        -e "s|^SECRET_KEY_BASE=.*$|SECRET_KEY_BASE=${secret_key_base}|" \
        -e "s|^VAULT_ENC_KEY=.*$|VAULT_ENC_KEY=${vault_enc_key}|" \
        -e "s|^PG_META_CRYPTO_KEY=.*$|PG_META_CRYPTO_KEY=${pg_meta_crypto_key}|" \
        -e "s|^LOGFLARE_PUBLIC_ACCESS_TOKEN=.*$|LOGFLARE_PUBLIC_ACCESS_TOKEN=${logflare_public_access_token}|" \
        -e "s|^LOGFLARE_PRIVATE_ACCESS_TOKEN=.*$|LOGFLARE_PRIVATE_ACCESS_TOKEN=${logflare_private_access_token}|" \
        -e "s|^S3_PROTOCOL_ACCESS_KEY_ID=.*$|S3_PROTOCOL_ACCESS_KEY_ID=${s3_protocol_access_key_id}|" \
        -e "s|^S3_PROTOCOL_ACCESS_KEY_SECRET=.*$|S3_PROTOCOL_ACCESS_KEY_SECRET=${s3_protocol_access_key_secret}|" \
        -e "s|^POSTGRES_PASSWORD=.*$|POSTGRES_PASSWORD=${postgres_password}|" \
        -e "s|^DASHBOARD_PASSWORD=.*$|DASHBOARD_PASSWORD=${dashboard_password}|" \
        "$ENV_EXAMPLE" > "$ENV_COOLIFY"
}

main() {
    # Main script logic
    ENV_EXAMPLE=".env.example"
    ENV_COOLIFY=".env.coolify"

    require_openssl
    generate_secrets
    print_secrets
    replace_env_secrets

    echo "Generated $ENV_COOLIFY with new secrets."
}

main "$@"
