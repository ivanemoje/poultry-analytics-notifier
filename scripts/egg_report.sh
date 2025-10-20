#!/bin/bash

set -e

# Required environment variables
: "${ONA_API_TOKEN:?Missing ONA_API_TOKEN}"
: "${ONA_FORM_ID:?Missing ONA_FORM_ID}"

URL="https://api.ona.io/api/v1/data/$ONA_FORM_ID"
response=$(curl -s -H "Authorization: Token $ONA_API_TOKEN" "$URL")

latest=$(echo "$response" | jq 'sort_by(._submission_time) | last')
latest_trays=$(echo "$latest" | jq -r '.numbertrays')
latest_eggs=$(echo "$latest" | jq -r '.numbereggs')
latest_eggs_broken=$(echo "$latest" | jq -r '.numbereggsbroken')
latest_date=$(echo "$latest" | jq -r '.surveydate')
latest_time=$(echo "$latest" | jq -r '._submission_time' | xargs -I{} date -d "{} +3 hours" +"%Y-%m-%d %H:%M")

today=$(date -u +"%Y-%m-%d")
three_days_ago=$(date -u -d "-3 days" +"%Y-%m-%d")
seven_days_ago=$(date -u -d "-7 days" +"%Y-%m-%d")
thirty_days_ago=$(date -u -d "-30 days" +"%Y-%m-%d")
yesterday=$(date -u -d "yesterday" +"%Y-%m-%d")

total_trays=0
total_eggs=0
total_eggs_broken=0
three_day_total_eggs=0
seven_day_total_eggs=0
thirty_day_total_eggs=0
yesterday_total_eggs=0
yesterday_count=0

# Number of birds
total_birds=576

mapfile -t records < <(echo "$response" | jq -c '.[]')
for record in "${records[@]}"; do
  trays=$(echo "$record" | jq -r '.numbertrays')
  eggs=$(echo "$record" | jq -r '.numbereggs')
  eggsbroken=$(echo "$record" | jq -r '.numbereggsbroken')
  date=$(echo "$record" | jq -r '.surveydate')

  total_trays=$((total_trays + trays))
  total_eggs=$((total_eggs + eggs))
  total_eggs_broken=$((total_eggs + eggsbroken))

  record_total_eggs=$((trays * 30 + eggs))

  [[ "$date" > "$three_days_ago" ]] && three_day_total_eggs=$((three_day_total_eggs + record_total_eggs))
  [[ "$date" > "$seven_days_ago" ]] && seven_day_total_eggs=$((seven_day_total_eggs + record_total_eggs))
  [[ "$date" > "$thirty_days_ago" ]] && thirty_day_total_eggs=$((thirty_day_total_eggs + record_total_eggs))

  if [[ "$date" == "$yesterday" ]]; then
    yesterday_total_eggs=$((yesterday_total_eggs + record_total_eggs))
    yesterday_count=$((yesterday_count + 1))
  fi
done

count_3=$(echo "$response" | jq "[.[] | select(.surveydate > \"$three_days_ago\")] | length")
count_7=$(echo "$response" | jq "[.[] | select(.surveydate > \"$seven_days_ago\")] | length")
count_30=$(echo "$response" | jq "[.[] | select(.surveydate > \"$thirty_days_ago\")] | length")

avg3_eggs=$(( count_3 > 0 ? three_day_total_eggs / count_3 : 0 ))
avg7_eggs=$(( count_7 > 0 ? seven_day_total_eggs / count_7 : 0 ))
avg30_eggs=$(( count_30 > 0 ? thirty_day_total_eggs / count_30 : 0 ))
yesterday_avg_eggs=$(( yesterday_count > 0 ? yesterday_total_eggs / yesterday_count : 0 ))

# Calculate today's average eggs
today_total_eggs=0
today_count=0
for record in "${records[@]}"; do
  trays=$(echo "$record" | jq -r '.numbertrays')
  eggs=$(echo "$record" | jq -r '.numbereggs')
  date=$(echo "$record" | jq -r '.surveydate')
  record_total_eggs=$((trays * 30 + eggs))
  if [[ "$date" == "$today" ]]; then
    today_total_eggs=$((today_total_eggs + record_total_eggs))
    today_count=$((today_count + 1))
  fi
done
today_avg_eggs=$(( today_count > 0 ? today_total_eggs / today_count : 0 ))

# Compare today's average to each rolling average
if (( today_avg_eggs > yesterday_avg_eggs )); then
  arrow_yesterday="✅"
elif (( today_avg_eggs < yesterday_avg_eggs )); then
  arrow_yesterday="❌"
elif (( today_avg_eggs == yesterday_avg_eggs )); then
  arrow_yesterday="🔵"
else
  arrow_yesterday="❌"
fi

if (( today_avg_eggs > avg3_eggs )); then
  arrow3="✅"
elif (( today_avg_eggs < avg3_eggs )); then
  arrow3="❌"
elif (( today_avg_eggs == avg3_eggs )); then
  arrow3="🔵"
else
  arrow3="❌"
fi

if (( today_avg_eggs > avg7_eggs )); then
  arrow7="✅"
elif (( today_avg_eggs < avg7_eggs )); then
  arrow7="❌"
elif (( today_avg_eggs == avg7_eggs )); then
  arrow7="🔵"
else
  arrow7="❌"
fi

if (( today_avg_eggs > avg30_eggs )); then
  arrow30="✅"
elif (( today_avg_eggs < avg30_eggs )); then
  arrow30="❌"
elif (( today_avg_eggs == avg30_eggs )); then
  arrow30="🔵"
else
  arrow30="❌"
fi

# Calculate total eggs for all records (trays*30 + eggs)
total_eggs_all=0
for record in "${records[@]}"; do
  trays=$(echo "$record" | jq -r '.numbertrays')
  eggs=$(echo "$record" | jq -r '.numbereggs')
  total_eggs_all=$((total_eggs_all + trays * 30 + eggs))
done
total_trays_calc=$(( total_eggs_all / 30 ))
total_eggs_mod=$(( total_eggs_all % 30 ))

# Calculate laying percentage

# --- DEBUG LINES START ---
echo "DEBUG: Total Birds: $total_birds" >&2 # Sends output to stderr
echo "DEBUG: Today Total Eggs: $today_total_eggs" >&2
# --- DEBUG LINES END ---


# laying_percentage=$(( today_total_eggs * 100 / (total_birds) ))
laying_percentage=$(echo "scale=2; ($today_total_eggs * 100) / $total_birds" | bc)
laying_percentage_7day=$(( seven_day_total_eggs * 100 / (total_birds * 7) ))

cat <<EOF
*🐣 Egg Report Summary*


*Reporting for: \`$today\`*


📅 Survey Date: \`$latest_date\`


🧺 Trays: \`$latest_trays\`

🥚 Eggs: \`$latest_eggs\`

🔴 Broken: \`$latest_eggs_broken\`

📊 Laying Percentage (today): \`$laying_percentage%\`


🥚 Total Eggs (this entry): \`$((latest_trays * 30 + latest_eggs))\`


*Totals (All Records):*


🥚 Total Eggs: \`$total_eggs_all\`

🧺 Trays: \`$total_trays_calc\`, 🥚 Remaining Eggs: \`$total_eggs_mod\`


*📅 Rolling Averages for eggs (trays counted as 30 eggs each)*


🗓️ Yesterday's average eggs: \`$yesterday_avg_eggs\` $arrow_yesterday

⏱️ 3-Day average eggs: \`$avg3_eggs\` $arrow3

⏱️ 7-Day average eggs: \`$avg7_eggs\` $arrow7

⏱️ 30-Day average eggs: \`$avg30_eggs\` $arrow30


📅  Data submitted at: \`$latest_time\`
EOF