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
three_day_eggs=0
seven_day_eggs=0

mapfile -t records < <(echo "$response" | jq -c '.[]')
for record in "${records[@]}"; do
  trays=$(echo "$record" | jq -r '.numbertrays')
  eggs=$(echo "$record" | jq -r '.numbereggs')
  date=$(echo "$record" | jq -r '.surveydate')

  total_trays=$((total_trays + trays))
  total_eggs=$((total_eggs + eggs))

  [[ "$date" > "$three_days_ago" ]] && three_day_eggs=$((three_day_eggs + eggs))
  [[ "$date" > "$seven_days_ago" ]] && seven_day_eggs=$((seven_day_eggs + eggs))
done

# Adjust tray count if total eggs exceed 30
if (( total_eggs > 30 )); then
  extra_trays=$(( (total_eggs + 29) / 30 - total_trays ))
  (( extra_trays > 0 )) && total_trays=$(( total_trays + extra_trays ))
fi

count_3=$(echo "$response" | jq "[.[] | select(.surveydate > \"$three_days_ago\")] | length")
count_7=$(echo "$response" | jq "[.[] | select(.surveydate > \"$seven_days_ago\")] | length")

avg3=$(( count_3 > 0 ? three_day_eggs / count_3 : 0 ))
avg7=$(( count_7 > 0 ? seven_day_eggs / count_7 : 0 ))

cat <<EOF
*🐣 Egg Report Summary*


*Latest Record:*
🧺 Trays: \`$latest_trays\`

🥚 Eggs: \`$latest_eggs\`

📅 Survey Date: \`$latest_date\`


*Totals:*
🧺 Total Trays: \`$total_trays\`

🥚 Total Eggs: \`$total_eggs\`

*📊 Averages:*
⏱️ 3-Day total Eggs: \`$avg3\`

⏱️ 7-Day total Eggs: \`$avg7\`

⏱️ Submission Time: \`$latest_time\`
EOF
