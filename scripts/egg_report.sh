#!/bin/bash

set -e

# Required environment variable
: "${ONA_API_TOKEN:?Missing ONA_API_TOKEN}"

URL="https://api.ona.io/api/v1/data/848851"
response=$(curl -s -H "Authorization: Token $ONA_API_TOKEN" "$URL")

latest=$(echo "$response" | jq 'sort_by(._submission_time) | last')
latest_trays=$(echo "$latest" | jq -r '.numbertrays')
latest_eggs=$(echo "$latest" | jq -r '.numbereggs')
latest_date=$(echo "$latest" | jq -r '.surveydate')
latest_time=$(echo "$latest" | jq -r '._submission_time')

today=$(date -u +"%Y-%m-%d")
three_days_ago=$(date -u -d "-3 days" +"%Y-%m-%d")
seven_days_ago=$(date -u -d "-7 days" +"%Y-%m-%d")

total_trays=0
total_eggs=0
three_day_total_eggs=0
seven_day_total_eggs=0

mapfile -t records < <(echo "$response" | jq -c '.[]')
for record in "${records[@]}"; do
  trays=$(echo "$record" | jq -r '.numbertrays')
  eggs=$(echo "$record" | jq -r '.numbereggs')
  date=$(echo "$record" | jq -r '.surveydate')

  total_trays=$((total_trays + trays))
  total_eggs=$((total_eggs + eggs))

  record_total_eggs=$((trays * 30 + eggs))

  [[ "$date" > "$three_days_ago" ]] && three_day_total_eggs=$((three_day_total_eggs + record_total_eggs))
  [[ "$date" > "$seven_days_ago" ]] && seven_day_total_eggs=$((seven_day_total_eggs + record_total_eggs))
done

count_3=$(echo "$response" | jq "[.[] | select(.surveydate > \"$three_days_ago\")] | length")
count_7=$(echo "$response" | jq "[.[] | select(.surveydate > \"$seven_days_ago\")] | length")

avg3_eggs=$(( count_3 > 0 ? three_day_total_eggs / count_3 : 0 ))
avg7_eggs=$(( count_7 > 0 ? seven_day_total_eggs / count_7 : 0 ))

cat <<EOF
*🐣 Egg Report Summary*


*Latest Record, 📅 Survey Date:\`$latest_date\`*


🧺 Trays: \`$latest_trays\`

🥚 Eggs: \`$latest_eggs\`


*Totals:*


🧺 Total Trays: \`$total_trays\`

🥚 Total Eggs: \`$total_eggs\`


*📅 Rolling Averages (eggs, trays counted as 30 eggs each)*


⏱️ 3-Day average eggs: \`$avg3_eggs\`

⏱️ 7-Day average eggs: \`$avg7_eggs\`

📅  Data submitted at: \`$latest_time\`
EOF