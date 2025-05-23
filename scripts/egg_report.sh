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
latest_date=$(echo "$latest" | jq -r '.surveydate')
latest_time=$(echo "$latest" | jq -r '._submission_time' | xargs -I{} date -d "{} +3 hours" +"%Y-%m-%d %H:%M")

today=$(date -u +"%Y-%m-%d")
three_days_ago=$(date -u -d "-3 days" +"%Y-%m-%d")
seven_days_ago=$(date -u -d "-7 days" +"%Y-%m-%d")
thirty_days_ago=$(date -u -d "-30 days" +"%Y-%m-%d")
yesterday=$(date -u -d "yesterday" +"%Y-%m-%d")

total_trays=0
total_eggs=0
three_day_total_eggs=0
seven_day_total_eggs=0
thirty_day_total_eggs=0
yesterday_total_eggs=0
yesterday_count=0

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

# Calculate previous 3-day, 7-day, and 30-day periods
prev_three_days_start=$(date -u -d "-6 days" +"%Y-%m-%d")
prev_three_days_end=$(date -u -d "-3 days" +"%Y-%m-%d")
prev_seven_days_start=$(date -u -d "-14 days" +"%Y-%m-%d")
prev_seven_days_end=$(date -u -d "-7 days" +"%Y-%m-%d")
prev_thirty_days_start=$(date -u -d "-60 days" +"%Y-%m-%d")
prev_thirty_days_end=$(date -u -d "-30 days" +"%Y-%m-%d")

prev_three_day_total_eggs=0
prev_seven_day_total_eggs=0
prev_thirty_day_total_eggs=0
prev_count_3=0
prev_count_7=0
prev_count_30=0

for record in "${records[@]}"; do
  trays=$(echo "$record" | jq -r '.numbertrays')
  eggs=$(echo "$record" | jq -r '.numbereggs')
  date=$(echo "$record" | jq -r '.surveydate')
  record_total_eggs=$((trays * 30 + eggs))

  if [[ "$date" > "$prev_three_days_start" && ( "$date" < "$prev_three_days_end" || "$date" == "$prev_three_days_end" ) ]]; then
    prev_three_day_total_eggs=$((prev_three_day_total_eggs + record_total_eggs))
    prev_count_3=$((prev_count_3 + 1))
  fi
  if [[ "$date" > "$prev_seven_days_start" && ( "$date" < "$prev_seven_days_end" || "$date" == "$prev_seven_days_end" ) ]]; then
    prev_seven_day_total_eggs=$((prev_seven_day_total_eggs + record_total_eggs))
    prev_count_7=$((prev_count_7 + 1))
  fi
  if [[ "$date" > "$prev_thirty_days_start" && ( "$date" < "$prev_thirty_days_end" || "$date" == "$prev_thirty_days_end" ) ]]; then
    prev_thirty_day_total_eggs=$((prev_thirty_day_total_eggs + record_total_eggs))
    prev_count_30=$((prev_count_30 + 1))
  fi
done

prev_avg3_eggs=$(( prev_count_3 > 0 ? prev_three_day_total_eggs / prev_count_3 : 0 ))
prev_avg7_eggs=$(( prev_count_7 > 0 ? prev_seven_day_total_eggs / prev_count_7 : 0 ))
prev_avg30_eggs=$(( prev_count_30 > 0 ? prev_thirty_day_total_eggs / prev_count_30 : 0 ))

# Determine arrows for rolling averages
if (( avg3_eggs > prev_avg3_eggs )); then
  arrow3="✅"
elif (( avg3_eggs < prev_avg3_eggs )); then
  arrow3="❌"
else
  arrow3="🔵"
fi

if (( avg7_eggs > prev_avg7_eggs )); then
  arrow7="✅"
elif (( avg7_eggs < prev_avg7_eggs )); then
  arrow7="❌"
else
  arrow7="🔵"
fi

if (( avg30_eggs > prev_avg30_eggs )); then
  arrow30="✅"
elif (( avg30_eggs < prev_avg30_eggs )); then
  arrow30="❌"
else
  arrow30="🔵"
fi

# Calculate yesterday vs day before yesterday
day_before_yesterday=$(date -u -d "2 days ago" +"%Y-%m-%d")
day_before_yesterday_total_eggs=0
day_before_yesterday_count=0

for record in "${records[@]}"; do
  trays=$(echo "$record" | jq -r '.numbertrays')
  eggs=$(echo "$record" | jq -r '.numbereggs')
  date=$(echo "$record" | jq -r '.surveydate')
  record_total_eggs=$((trays * 30 + eggs))

  if [[ "$date" == "$day_before_yesterday" ]]; then
    day_before_yesterday_total_eggs=$((day_before_yesterday_total_eggs + record_total_eggs))
    day_before_yesterday_count=$((day_before_yesterday_count + 1))
  fi
done

day_before_yesterday_avg_eggs=$(( day_before_yesterday_count > 0 ? day_before_yesterday_total_eggs / day_before_yesterday_count : 0 ))

# FIXED LOGIC: ✅ for improvement, ❌ for worse, 🔵 for equal
if (( yesterday_avg_eggs > day_before_yesterday_avg_eggs )); then
  arrow_yesterday="✅"
elif (( yesterday_avg_eggs < day_before_yesterday_avg_eggs )); then
  arrow_yesterday="❌"
else
  arrow_yesterday="🔵"
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

cat <<EOF
*🐣 Egg Report Summary*


*Reporting for: \`$today\`*


📅 Survey Date: \`$latest_date\`


🧺 Trays: \`$latest_trays\`
🥚 Eggs: \`$latest_eggs\`

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