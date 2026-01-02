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
batch_three_birds=407
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

# Calculate batch-specific daily eggs and laying percentages
batch1_daily_eggs=$((latest_trays * 30 + latest_eggs))
batch2_daily_eggs=$((latest_trays_batch2 * 30 + latest_eggs_batch2))
total_daily_eggs=$((batch1_daily_eggs + batch2_daily_eggs))

laying_percentage_batch1=$(echo "scale=2; ($batch1_daily_eggs / $batch_one_birds) * 100" | bc)
laying_percentage_batch2=$(echo "scale=2; ($batch2_daily_eggs / $batch_two_birds) * 100" | bc)
laying_percentage_daily=$(echo "scale=2; ($total_daily_eggs / $total_birds) * 100" | bc)

cat <<EOF
*:hatching_chick: Egg Report Summary*
*Reporting for:* \`$today\`

:calendar: Survey Date: \`$latest_date\`

*Batch 1:*
:basket: Trays: \`$latest_trays\`
:egg: Eggs: \`$latest_eggs\`
:red_circle: Broken: \`$latest_eggs_broken\`
:chart_with_upwards_trend: Laying %: \`$laying_percentage_batch1%\`

*Batch 2*
:basket: Trays: \`$latest_trays_batch2\`
:egg: Eggs: \`$latest_eggs_batch2\`
:red_circle: Broken: \`$latest_eggs_broken_batch2\`
:chart_with_upwards_trend: Laying %: \`$laying_percentage_batch2%\`

*Combined*
:egg: Total Eggs (this entry): \`$total_daily_eggs\`
:chart_with_upwards_trend: Laying Percentage (today): \`$laying_percentage_daily%\`

*Totals (All Records):*
:egg: Total Eggs: \`$total_eggs_all\`
:basket: Trays: \`$total_trays_calc\` | :egg: Remaining Eggs: \`$total_eggs_mod\`

*:calendar: Rolling Averages (combined batches)*
:spiral_calendar_pad: Yesterday avg: \`$yesterday_avg_eggs\` $arrow_yesterday
:stopwatch: 3-Day avg: \`$avg3_eggs\` $arrow3
:stopwatch: 7-Day avg: \`$avg7_eggs\` $arrow7
:stopwatch: 30-Day avg: \`$avg30_eggs\` $arrow30

:calendar: Data submitted at: \`$latest_time\`
EOF

# 1. Define the output file path
OUTPUT_FILE="poultry_analytics_data.json"

# Load optional batch metadata from file (dateOfBirth, supplier, etc.)
BATCH_METADATA_FILE="batch_metadata.json"
if [ -f "$BATCH_METADATA_FILE" ]; then
  batch_metadata_json=$(cat "$BATCH_METADATA_FILE")
else
  batch_metadata_json='{"batch1":{"dateOfBirth":"","supplier":""},"batch2":{"dateOfBirth":"","supplier":""},"batch3":{"dateOfBirth":"","supplier":""}}'
fi

# 2. Construct and write the JSON data
jq -n \
  --arg today "$today" \
  --arg latest_date "$latest_date" \
  --argjson latest_trays "$latest_trays" \
  --argjson latest_eggs "$latest_eggs" \
  --argjson latest_broken "$latest_eggs_broken" \
  --argjson latest_trays_batch2 "$latest_trays_batch2" \
  --argjson latest_eggs_batch2 "$latest_eggs_batch2" \
  --argjson latest_broken_batch2 "$latest_eggs_broken_batch2" \
  --argjson batch1_daily "$batch1_daily_eggs" \
  --argjson batch2_daily "$batch2_daily_eggs" \
  --argjson total_daily "$total_daily_eggs" \
  --arg daily_perc "$laying_percentage_daily" \
  --arg batch1_perc "$laying_percentage_batch1" \
  --arg batch2_perc "$laying_percentage_batch2" \
  --argjson seven_day_total "$seven_day_total_eggs" \
  --argjson thirty_day_total "$thirty_day_total_eggs" \
  --argjson total_eggs_all "$total_eggs_all" \
  --argjson total_trays_calc "$total_trays_calc" \
  --argjson total_eggs_mod "$total_eggs_mod" \
  --argjson total_trays_b1 "$total_trays" \
  --argjson total_eggs_b1 "$total_eggs" \
  --argjson total_broken_b1 "$total_eggs_broken" \
  --argjson total_trays_b2 "$total_trays_batch2" \
  --argjson total_eggs_b2 "$total_eggs_batch2" \
  --argjson total_broken_b2 "$total_eggs_broken_batch2" \
  --argjson yesterday_avg "$yesterday_avg_eggs" \
  --arg arrow_yesterday "$arrow_yesterday" \
  --argjson avg3 "$avg3_eggs" \
  --arg arrow3 "$arrow3" \
  --argjson avg7 "$avg7_eggs" \
  --arg arrow7 "$arrow7" \
  --argjson avg30 "$avg30_eggs" \
  --arg arrow30 "$arrow30" \
  --arg latest_time "$latest_time" \
  --argjson batchStats "$batch_metadata_json" \
'{
  "reportDate": $today,
  "latestEntry": {
    "surveyDate": $latest_date,
    "batch1": {
      "trays": $latest_trays,
      "eggs": $latest_eggs,
      "broken": $latest_broken,
      "totalEggs": $batch1_daily,
      "layingPercentage": $batch1_perc
    },
    "batch2": {
      "trays": $latest_trays_batch2,
      "eggs": $latest_eggs_batch2,
      "broken": $latest_broken_batch2,
      "totalEggs": $batch2_daily,
      "layingPercentage": $batch2_perc
    },
    "combined": {
      "totalEggsEntry": $total_daily,
      "layingPercentageDaily": $daily_perc
    },
    "submittedAt": $latest_time
  },
  "overallTotals": {
    "batch1": {
      "trays": $total_trays_b1,
      "eggs": $total_eggs_b1,
      "broken": $total_broken_b1
    },
    "batch2": {
      "trays": $total_trays_b2,
      "eggs": $total_eggs_b2,
      "broken": $total_broken_b2
    },
    "combined": {
      "totalEggsAllRecords": $total_eggs_all,
      "totalTraysCalculated": $total_trays_calc,
      "remainingEggs": $total_eggs_mod
    }
  },
  "recentTotals": {
    "sevenDay": $seven_day_total,
    "thirtyDay": $thirty_day_total
  },
  "rollingAverages": {
    "yesterday": {
      "average": $yesterday_avg,
      "trend": $arrow_yesterday
    },
    "threeDay": {
      "average": $avg3,
      "trend": $arrow3
    },
    "sevenDay": {
      "average": $avg7,
      "trend": $arrow7
    },
    "thirtyDay": {
      "average": $avg30,
      "trend": $arrow30
    }
  }
  ,
  "batchStats": $batchStats
}' > "$OUTPUT_FILE"

# Verify the file was written successfully
if [ -s "$OUTPUT_FILE" ]; then
  echo "✓ JSON data successfully written to $OUTPUT_FILE"
  echo "File size: $(wc -c < "$OUTPUT_FILE") bytes"
else
  echo "✗ ERROR: $OUTPUT_FILE is empty or was not created"
  exit 1
fi