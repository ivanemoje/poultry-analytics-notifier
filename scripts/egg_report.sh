#!/bin/bash

set -euo pipefail

# Fetch data from Ona
DATA=$(curl -s -H "Authorization: Token $ONA_API_TOKEN" https://api.ona.io/api/v1/data/848851)

# Parse and sort records by _submission_time
SORTED=$(echo "$DATA" | jq -S 'sort_by(._submission_time)')

# Total stats
TOTAL_TRAYS=0
TOTAL_EGGS=0
TOTAL_RECORDS=$(echo "$SORTED" | jq 'length')

# Time-based aggregation
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
THREE_DAYS_AGO=$(date -u -d "-3 days" +"%Y-%m-%dT%H:%M:%SZ")
SEVEN_DAYS_AGO=$(date -u -d "-7 days" +"%Y-%m-%dT%H:%M:%SZ")

THREE_DAY_EGGS=0
THREE_DAY_COUNT=0
SEVEN_DAY_EGGS=0
SEVEN_DAY_COUNT=0

for row in $(echo "$SORTED" | jq -c '.[]'); do
  TRAYS=$(echo "$row" | jq '.numbertrays')
  EGGS=$(echo "$row" | jq '.numbereggs')
  SUBMIT_TIME=$(echo "$row" | jq -r '._submission_time')

  # Normalize tray count (each tray = 30 eggs)
  TOTAL_TRAYS=$((TOTAL_TRAYS + TRAYS))
  TOTAL_EGGS=$((TOTAL_EGGS + TRAYS * 30 + EGGS))

  if [[ "$SUBMIT_TIME" > "$SEVEN_DAYS_AGO" ]]; then
    SEVEN_DAY_EGGS=$((SEVEN_DAY_EGGS + TRAYS * 30 + EGGS))
    SEVEN_DAY_COUNT=$((SEVEN_DAY_COUNT + 1))
  fi
  if [[ "$SUBMIT_TIME" > "$THREE_DAYS_AGO" ]]; then
    THREE_DAY_EGGS=$((THREE_DAY_EGGS + TRAYS * 30 + EGGS))
    THREE_DAY_COUNT=$((THREE_DAY_COUNT + 1))
  fi
done

# Latest record
LATEST=$(echo "$SORTED" | jq '.[-1]')
LATEST_TRAYS=$(echo "$LATEST" | jq '.numbertrays')
LATEST_EGGS=$(echo "$LATEST" | jq '.numbereggs')
LATEST_SURVEY_DATE=$(echo "$LATEST" | jq -r '.surveydate')
LATEST_SUBMIT_TIME=$(echo "$LATEST" | jq -r '._submission_time')

# Averages
AVG_3DAY=$(if [ "$THREE_DAY_COUNT" -gt 0 ]; then echo $((THREE_DAY_EGGS / THREE_DAY_COUNT)); else echo "n/a"; fi)
AVG_7DAY=$(if [ "$SEVEN_DAY_COUNT" -gt 0 ]; then echo $((SEVEN_DAY_EGGS / SEVEN_DAY_COUNT)); else echo "n/a"; fi)

# Format for Slack
cat <<EOF
*📊 Daily Egg Collection Report*

*Latest Record:*
• 🥚 Number of trays: *$LATEST_TRAYS*
• 🍳 Extra eggs: *$LATEST_EGGS*
• 📅 Survey date: *$LATEST_SURVEY_DATE*
• 🕒 Submitted at: *$LATEST_SUBMIT_TIME*

*Totals ($TOTAL_RECORDS records):*
• 📦 Trays: *$TOTAL_TRAYS*
• 🥚 Eggs (adjusted): *$TOTAL_EGGS*

*Averages:*
• 📆 3-day avg: *$AVG_3DAY*
• 📆 7-day avg: *$AVG_7DAY*
EOF
