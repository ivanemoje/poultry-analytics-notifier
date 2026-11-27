#!/bin/bash
set -euo pipefail

: "${ONA_API_TOKEN:?Missing ONA_API_TOKEN}"
: "${ONA_FORM_ID:?Missing ONA_FORM_ID}"

fetch_form() {
  curl -fsS -H "Authorization: Token $ONA_API_TOKEN" "https://api.ona.io/api/v1/data/$1"
}

production=$(fetch_form "$ONA_FORM_ID")
sales=$(fetch_form "${SALES_ONA_FORM_ID:-853534}")
expenses=$(fetch_form "${EXPENSES_ONA_FORM_ID:-856758}")
printf '{"production":%s,"sales":%s,"expenses":%s}\n' "$production" "$sales" "$expenses" | python3 scripts/poultry_analytics.py
