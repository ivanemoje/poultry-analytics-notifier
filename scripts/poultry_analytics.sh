#!/bin/bash
set -euo pipefail

: "${ONA_API_TOKEN:?Missing ONA_API_TOKEN}"
: "${ONA_FORM_ID:?Missing ONA_FORM_ID}"

URL="https://api.ona.io/api/v1/data/$ONA_FORM_ID"
response=$(curl -fsS -H "Authorization: Token $ONA_API_TOKEN" "$URL")
python3 scripts/poultry_analytics.py <<< "$response"
