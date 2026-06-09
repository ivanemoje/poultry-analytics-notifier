#!/bin/bash
set -e

: "${ONA_API_TOKEN:?Missing ONA_API_TOKEN}"
: "${SALES_ONA_FORM_ID:?Missing SALES_ONA_FORM_ID}"

URL="https://api.ona.io/api/v1/data/$SALES_ONA_FORM_ID"
response=$(curl -s -H "Authorization: Token $ONA_API_TOKEN" "$URL")

today=$(date -u +"%Y-%m-%d")

# Process Latest Entry
latest=$(echo "$response" | jq 'sort_by(._submission_time) | last')
latestsurveydate=$(echo "$latest" | jq -r '.surveydate // empty')
latestsubmissiontime=$(echo "$latest" | jq -r '._submission_time' | xargs -I{} date -d "{} +3 hours" +"%Y-%m-%d %H:%M")

# Latest entry values
latestcategory=$(echo "$latest" | jq -r '.category // empty')
latestsubcategory=$(echo "$latest" | jq -r '.subcategory // empty')
latestpaymentmode=$(echo "$latest" | jq -r '.paymentmode // empty')
latestamount=$(echo "$latest" | jq -r '.amount // 0')
latestnumtrays=$(echo "$latest" | jq -r '.numtrays // 0')
latestnumanimals=$(echo "$latest" | jq -r '.numanimals // 0')
latestcomments=$(echo "$latest" | jq -r '.comments // empty')

# Fix: Use jq to calculate total instead of a broken bash loop
totalamountall=$(echo "$response" | jq '[.[].amount | tonumber] | add')

# Generate summary report (Console)
cat <<EOF
*:hatching_chick: Poultry Sales Summary*
*Reporting for:* \`$today\`

:calendar: Survey Date: \`$latestsurveydate\`

*Latest Record:*
:moneybag: Amount: \`$latestamount\`
:label: Category: \`$latestcategory\`
:comment: Comments: \`$latestcomments\`

:moneybag: Total Sales (All Records): \`$totalamountall\`
:calendar: Data submitted at: \`$latestsubmissiontime\`
EOF

# JSON Output Logic
OUTPUT_FILE="poultry_sales_data.json"
BATCH_METADATA_FILE="config/batch_sales_metadata.json"

if [ -f "$BATCH_METADATA_FILE" ]; then
  batch_metadata_json=$(cat "$BATCH_METADATA_FILE")
else
  batch_metadata_json='{"batch1":{"dateOfBirth":"","supplier":""}}'
fi

sales_records_json=$(echo "$response" | jq '
  def n: tonumber? // 0;
  def text: tostring | ascii_upcase;
  def is_expense:
    ((.type // .category // .subcategory // .expense // "" | text) | test("EXPENSE|COST|FEED|VET|VACCINE|TRANSPORT|MAIZE|BRAN|HUSK|LIME|CALCIUM|VITAMIN|CHARCOAL|CONCENTRATE|DEWORMER|CHICKS"));
  sort_by(.surveydate // ._submission_time // "") |
  map(select(is_expense | not) | {
    date: (.surveydate // ""),
    amount: (.amount | n),
    payment: (.paymentmode // .payment // ""),
    category: (.category // ""),
    subcategory: (.subcategory // ""),
    trays: (.numtrays | n),
    animals: (.numanimals | n),
    comments: (.comments // ""),
    submittedAt: (._submission_time // "")
  })
')

expense_records_json=$(echo "$response" | jq '
  def n: tonumber? // 0;
  def text: tostring | ascii_upcase;
  def is_expense:
    ((.type // .category // .subcategory // .expense // "" | text) | test("EXPENSE|COST|FEED|VET|VACCINE|TRANSPORT|MAIZE|BRAN|HUSK|LIME|CALCIUM|VITAMIN|CHARCOAL|CONCENTRATE|DEWORMER|CHICKS"));
  sort_by(.surveydate // ._submission_time // "") |
  map(select(is_expense) | {
    date: (.surveydate // ""),
    expense: (.expense // .subcategory // .category // "EXPENSE"),
    amount: (.amount | n),
    payment: (.paymentmode // .payment // ""),
    category: (.category // ""),
    comments: (.comments // ""),
    submittedAt: (._submission_time // "")
  })
')

# Construct JSON
jq -n \
  --arg today "$today" \
  --arg latestsurveydate "$latestsurveydate" \
  --arg latestcategory "$latestcategory" \
  --arg latestsubcategory "$latestsubcategory" \
  --arg latestpaymentmode "$latestpaymentmode" \
  --argjson latestamount "$latestamount" \
  --argjson latestnumtrays "$latestnumtrays" \
  --argjson latestnumanimals "$latestnumanimals" \
  --arg latestcomments "$latestcomments" \
  --arg latestsubmissiontime "$latestsubmissiontime" \
  --argjson totalamountall "$totalamountall" \
  --argjson batchStats "$batch_metadata_json" \
  --argjson salesRecords "$sales_records_json" \
  --argjson expenseRecords "$expense_records_json" \
'{
  "reportDate": $today,
  "latestEntry": {
    "surveyDate": $latestsurveydate,
    "latestsales": {
      "latestcategory": $latestcategory,
      "subcategory": $latestsubcategory,
      "paymentmode": $latestpaymentmode,
      "amount": $latestamount,
      "numtrays": $latestnumtrays,
      "numanimals": $latestnumanimals,
      "comments": $latestcomments
    },
    "combined": {
      "totalAmount": $totalamountall
    },
    "submittedAt": $latestsubmissiontime
  },
  "batchStats": $batchStats,
  "salesRecords": $salesRecords,
  "expenseRecords": $expenseRecords
}' > "$OUTPUT_FILE"

# Verify the file was written successfully
if [ -s "$OUTPUT_FILE" ]; then
  echo "✓ JSON data successfully written to $OUTPUT_FILE"
  echo "File size: $(wc -c < "$OUTPUT_FILE") bytes"
else
  echo "✗ ERROR: $OUTPUT_FILE is empty or was not created"
  exit 1
fi
