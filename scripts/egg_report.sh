#!/bin/bash
set -e

# Required environment variables
: "${ONA_API_TOKEN:?Missing ONA_API_TOKEN}"
: "${ONA_FORM_ID:?Missing ONA_FORM_ID}"

URL="https://api.ona.io/api/v1/data/$ONA_FORM_ID"
response=$(curl -s -H "Authorization: Token $ONA_API_TOKEN" "$URL")

latest=$(echo "$response" | jq 'sort_by(._submission_time) | last')

# --- Latest entry values ---
latest_trays=$(echo "$latest" | jq -r '.numbertrays')
latest_eggs=$(echo "$latest" | jq -r '.numbereggs')
latest_eggs_broken=$(echo "$latest" | jq -r '.numbereggsbroken')

latest_trays_batch2=$(echo "$latest" | jq -r '.numbertraysbatchtwo')
latest_eggs_batch2=$(echo "$latest" | jq -r '.numbereggsbatchtwo')
latest_eggs_broken_batch2=$(echo "$latest" | jq -r '.numbereggsbrokenbatchtwo')

latest_date=$(echo "$latest" | jq -r '.surveydate')
latest_time=$(echo "$latest" | jq -r '._submission_time' | xargs -I{} date -d "{} +3 hours" +"%Y-%m-%d %H:%M")

today=$(date -u +"%Y-%m-%d")
three_days_ago=$(date -u -d "-3 days" +"%Y-%m-%d")
seven_days_ago=$(date -u -d "-7 days" +"%Y-%m-%d")
thirty_days_ago=$(date -u -d "-30 days" +"%Y-%m-%d")
yesterday=$(date -u -d "yesterday" +"%Y-%m-%d")

# Totals
total_trays=0
total_eggs=0
total_eggs_broken=0

total_trays_batch2=0
total_eggs_batch2=0
total_eggs_broken_batch2=0

three_day_total_eggs=0
seven_day_total_eggs=0
thirty_day_total_eggs=0
yesterday_total_eggs=0
yesterday_count=0

# Number of birds
batch_one_birds=576
batch_two_birds=1064
total_birds=$((batch_one_birds + batch_two_birds))

mapfile -t records < <(echo "$response" | jq -c '.[]')

for record in "${records[@]}"; do
    trays=$(echo "$record" | jq -r '.numbertrays')
    eggs=$(echo "$record" | jq -r '.numbereggs')
    eggsbroken=$(echo "$record" | jq -r '.numbereggsbroken')

    trays2=$(echo "$record" | jq -r '.numbertraysbatchtwo')
    eggs2=$(echo "$record" | jq -r '.numbereggsbatchtwo')
    eggsbroken2=$(echo "$record" | jq -r '.numbereggsbrokenbatchtwo')

    total_trays=$((total_trays + trays))
    total_eggs=$((total_eggs + eggs))
    total_eggs_broken=$((total_eggs_broken + eggsbroken))

    total_trays_batch2=$((total_trays_batch2 + trays2))
    total_eggs_batch2=$((total_eggs_batch2 + eggs2))
    total_eggs_broken_batch2=$((total_eggs_broken_batch2 + eggsbroken2))

    date=$(echo "$record" | jq -r '.surveydate')
    record_total_eggs=$((trays * 30 + eggs + trays2 * 30 + eggs2))

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

# Today's averages
today_total_eggs=0
today_count=0
for record in "${records[@]}"; do
    trays=$(echo "$record" | jq -r '.numbertrays')
    eggs=$(echo "$record" | jq -r '.numbereggs')
    trays2=$(echo "$record" | jq -r '.numbertraysbatchtwo')
    eggs2=$(echo "$record" | jq -r '.numbereggsbatchtwo')
    date=$(echo "$record" | jq -r '.surveydate')
    record_total_eggs=$((trays * 30 + eggs + trays2 * 30 + eggs2))
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

# Combined totals
total_eggs_all=0
for record in "${records[@]}"; do
    trays=$(echo "$record" | jq -r '.numbertrays')
    eggs=$(echo "$record" | jq -r '.numbereggs')
    trays2=$(echo "$record" | jq -r '.numbertraysbatchtwo')
    eggs2=$(echo "$record" | jq -r '.numbereggsbatchtwo')
    total_eggs_all=$((total_eggs_all + trays * 30 + eggs + trays2 * 30 + eggs2))
done

total_trays_calc=$(( total_eggs_all / 30 ))
total_eggs_mod=$(( total_eggs_all % 30 ))

# Laying percentage (combined)
total_daily_eggs=$((latest_trays * 30 + latest_eggs + latest_trays_batch2 * 30 + latest_eggs_batch2))
laying_percentage_daily=$(echo "scale=2; ($total_daily_eggs / $total_birds) * 100" | bc)

cat <<EOF
*🐣 Egg Report Summary*
*Reporting for: \`$today\`*

📅 Survey Date: \`$latest_date\`

--- Batch 1 ---
🧺 Trays: \`$latest_trays\`
🥚 Eggs: \`$latest_eggs\`
🔴 Broken: \`$latest_eggs_broken\`

--- Batch 2 ---
🧺 Trays: \`$latest_trays_batch2\`
🥚 Eggs: \`$latest_eggs_batch2\`
🔴 Broken: \`$latest_eggs_broken_batch2\`

--- Combined ---
🥚 Total Eggs (this entry): \`$total_daily_eggs\`
📊 Laying Percentage (today): \`$laying_percentage_daily%\`

*Totals (All Records):*
🥚 Total Eggs: \`$total_eggs_all\`
🧺 Trays: \`$total_trays_calc\`, 🥚 Remaining Eggs: \`$total_eggs_mod\`

*📅 Rolling Averages (combined batches)*
🗓️ Yesterday's average eggs: \`$yesterday_avg_eggs\` $arrow_yesterday
⏱️ 3-Day average eggs: \`$avg3_eggs\` $arrow3
⏱️ 7-Day average eggs: \`$avg7_eggs\` $arrow7
⏱️ 30-Day average eggs: \`$avg30_eggs\` $arrow30

📅 Data submitted at: \`$latest_time\`
EOF

# 1. Define the output file path
OUTPUT_FILE="egg_report_data.json"

# 2. Construct the JSON data
JSON_DATA=$(jq -n \
  --arg today "$today" \
  --arg latest_date "$latest_date" \
  --arg latest_trays "$latest_trays" \
  --arg latest_eggs "$latest_eggs" \
  --arg latest_broken "$latest_eggs_broken" \
  --arg latest_trays_batch2 "$latest_trays_batch2" \
  --arg latest_eggs_batch2 "$latest_eggs_batch2" \
  --arg latest_broken_batch2 "$latest_eggs_broken_batch2" \
  --arg total_daily_eggs "$total_daily_eggs" \
  --arg laying_percentage_daily "$laying_percentage_daily" \
  --arg total_eggs_all "$total_eggs_all" \
  --arg total_trays_calc "$total_trays_calc" \
  --arg total_eggs_mod "$total_eggs_mod" \
  --arg yesterday_avg "$yesterday_avg_eggs" \
  --arg arrow_yesterday "$arrow_yesterday" \
  --arg avg3 "$avg3_eggs" \
  --arg arrow3 "$arrow3" \
  --arg avg7 "$avg7_eggs" \
  --arg arrow7 "$arrow7" \
  --arg avg30 "$avg30_eggs" \
  --arg arrow30 "$arrow30" \
  --arg latest_time "$latest_time" \
  '{
    "reportDate": $today,
    "latestEntry": {
      "surveyDate": $latest_date,
      "batch1": {
        "trays": ($latest_trays | tonumber),
        "eggs": ($latest_eggs | tonumber),
        "broken": ($latest_broken | tonumber)
      },
      "batch2": {
        "trays": ($latest_trays_batch2 | tonumber),
        "eggs": ($latest_eggs_batch2 | tonumber),
        "broken": ($latest_broken_batch2 | tonumber)
      },
      "combined": {
        "totalEggsEntry": ($total_daily_eggs | tonumber),
        "layingPercentageDaily": $laying_percentage_daily
      },
      "submittedAt": $latest_time
    },
    "overallTotals": {
      "batch1": {
        "trays": ($total_trays | tonumber),
        "eggs": ($total_eggs | tonumber),
        "broken": ($total_eggs_broken | tonumber)
      },
      "batch2": {
        "trays": ($total_trays_batch2 | tonumber),
        "eggs": ($total_eggs_batch2 | tonumber),
        "broken": ($total_eggs_broken_batch2 | tonumber)
      },
      "combined": {
        "totalEggsAllRecords": ($total_eggs_all | tonumber),
        "totalTraysCalculated": ($total_trays_calc | tonumber),
        "remainingEggs": ($total_eggs_mod | tonumber)
      }
    },
    "rollingAverages": {
      "yesterday": {
        "average": ($yesterday_avg | tonumber),
        "trend": $arrow_yesterday
      },
      "threeDay": {
        "average": ($avg3 | tonumber),
        "trend": $arrow3
      },
      "sevenDay": {
        "average": ($avg7 | tonumber),
        "trend": $arrow7
      },
      "thirtyDay": {
        "average": ($avg30 | tonumber),
        "trend": $arrow30
      }
    }
  }' | tee "$OUTPUT_FILE")