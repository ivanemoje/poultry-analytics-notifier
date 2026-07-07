#!/bin/bash
set -e

: "${ONA_API_TOKEN:?Missing ONA_API_TOKEN}"
: "${ONA_FORM_ID:?Missing ONA_FORM_ID}"

URL="https://api.ona.io/api/v1/data/$ONA_FORM_ID"
response=$(curl -s -H "Authorization: Token $ONA_API_TOKEN" "$URL")

latest=$(echo "$response" | jq 'sort_by(._submission_time) | last')

# --- Latest entry values ---
latest_trays=$(echo "$latest" | jq -r '.numbertrays // 0')
latest_eggs=$(echo "$latest" | jq -r '.numbereggs // 0')
latest_eggs_broken=$(echo "$latest" | jq -r '.numbereggsbroken // 0')

latest_trays_batch2=$(echo "$latest" | jq -r '.numbertraysbatchtwo // 0')
latest_eggs_batch2=$(echo "$latest" | jq -r '.numbereggsbatchtwo // 0')
latest_eggs_broken_batch2=$(echo "$latest" | jq -r '.numbereggsbrokenbatchtwo // 0')

latest_trays_batch3=$(echo "$latest" | jq -r '.numbertraysbatchthree // 0')
latest_eggs_batch3=$(echo "$latest" | jq -r '.numbereggsbatchthree // 0')
latest_eggs_broken_batch3=$(echo "$latest" | jq -r '.numbereggsbrokenbatchthree // 0')

latest_date=$(echo "$latest" | jq -r '.surveydate')
latest_time=$(echo "$latest" | jq -r '._submission_time' | xargs -I{} date -d "{} +3 hours" +"%Y-%m-%d %H:%M")

today=$(date -u +"%Y-%m-%d")
three_days_ago=$(date -u -d "-3 days" +"%Y-%m-%d")
seven_days_ago=$(date -u -d "-7 days" +"%Y-%m-%d")
thirty_days_ago=$(date -u -d "-30 days" +"%Y-%m-%d")
yesterday=$(date -u -d "yesterday" +"%Y-%m-%d")

# Totals
total_trays=0; total_eggs=0; total_eggs_broken=0
total_trays_batch2=0; total_eggs_batch2=0; total_eggs_broken_batch2=0
total_trays_batch3=0; total_eggs_batch3=0; total_eggs_broken_batch3=0

three_day_total_eggs=0; seven_day_total_eggs=0; thirty_day_total_eggs=0
yesterday_total_eggs=0; yesterday_count=0

# Number of birds
# to move to batch_metadata.json in future for dynamic updates
batch_one_birds=539
batch_two_birds=1027
batch_three_birds=390
total_birds=$((batch_one_birds + batch_two_birds + batch_three_birds))

mapfile -t records < <(echo "$response" | jq -c '.[]')

for record in "${records[@]}"; do
    trays=$(echo "$record" | jq -r '.numbertrays // 0')
    eggs=$(echo "$record" | jq -r '.numbereggs // 0')
    broken1=$(echo "$record" | jq -r '.numbereggsbroken // 0')

    trays2=$(echo "$record" | jq -r '.numbertraysbatchtwo // 0')
    eggs2=$(echo "$record" | jq -r '.numbereggsbatchtwo // 0')
    broken2=$(echo "$record" | jq -r '.numbereggsbrokenbatchtwo // 0')

    trays3=$(echo "$record" | jq -r '.numbertraysbatchthree // 0')
    eggs3=$(echo "$record" | jq -r '.numbereggsbatchthree // 0')
    broken3=$(echo "$record" | jq -r '.numbereggsbrokenbatchthree // 0')

    total_trays=$((total_trays + trays))
    total_eggs=$((total_eggs + eggs))
    total_eggs_broken=$((total_eggs_broken + broken1))

    total_trays_batch2=$((total_trays_batch2 + trays2))
    total_eggs_batch2=$((total_eggs_batch2 + eggs2))
    total_eggs_broken_batch2=$((total_eggs_broken_batch2 + broken2))

    total_trays_batch3=$((total_trays_batch3 + trays3))
    total_eggs_batch3=$((total_eggs_batch3 + eggs3))
    total_eggs_broken_batch3=$((total_eggs_broken_batch3 + broken3))

    date=$(echo "$record" | jq -r '.surveydate')
    record_total_eggs=$(( (trays * 30) + eggs + (trays2 * 30) + eggs2 + (trays3 * 30) + eggs3 ))

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
    date=$(echo "$record" | jq -r '.surveydate')
    if [[ "$date" == "$today" ]]; then
        t1=$(echo "$record" | jq -r '.numbertrays // 0')
        e1=$(echo "$record" | jq -r '.numbereggs // 0')
        t2=$(echo "$record" | jq -r '.numbertraysbatchtwo // 0')
        e2=$(echo "$record" | jq -r '.numbereggsbatchtwo // 0')
        t3=$(echo "$record" | jq -r '.numbertraysbatchthree // 0')
        e3=$(echo "$record" | jq -r '.numbereggsbatchthree // 0')
        
        record_total_eggs=$(( (t1 * 30) + e1 + (t2 * 30) + e2 + (t3 * 30) + e3 ))
        today_total_eggs=$((today_total_eggs + record_total_eggs))
        today_count=$((today_count + 1))
    fi
done
today_avg_eggs=$(( today_count > 0 ? today_total_eggs / today_count : 0 ))

# Helper for trends
get_arrow() {
  if (( $1 > $2 )); then echo "✅"; elif (( $1 < $2 )); then echo "❌"; else echo "🔵"; fi
}

arrow_yesterday=$(get_arrow $today_avg_eggs $yesterday_avg_eggs)
arrow3=$(get_arrow $today_avg_eggs $avg3_eggs)
arrow7=$(get_arrow $today_avg_eggs $avg7_eggs)
arrow30=$(get_arrow $today_avg_eggs $avg30_eggs)

# Combined totals
total_eggs_all=$(( (total_trays + total_trays_batch2 + total_trays_batch3) * 30 + total_eggs + total_eggs_batch2 + total_eggs_batch3 ))
total_trays_calc=$(( total_eggs_all / 30 ))
total_eggs_mod=$(( total_eggs_all % 30 ))

batch1_daily_eggs=$((latest_trays * 30 + latest_eggs))
batch2_daily_eggs=$((latest_trays_batch2 * 30 + latest_eggs_batch2))
batch3_daily_eggs=$((latest_trays_batch3 * 30 + latest_eggs_batch3))
total_daily_eggs=$((batch1_daily_eggs + batch2_daily_eggs + batch3_daily_eggs))

laying_percentage_batch1=$(echo "scale=2; ($batch1_daily_eggs / $batch_one_birds) * 100" | bc)
laying_percentage_batch2=$(echo "scale=2; ($batch2_daily_eggs / $batch_two_birds) * 100" | bc)
laying_percentage_batch3=$(echo "scale=2; ($batch3_daily_eggs / $batch_three_birds) * 100" | bc)
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

*Batch 3*
:basket: Trays: \`$latest_trays_batch3\`
:egg: Eggs: \`$latest_eggs_batch3\`
:red_circle: Broken: \`$latest_eggs_broken_batch3\`
:chart_with_upwards_trend: Laying %: \`$laying_percentage_batch3%\`

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

OUTPUT_FILE="poultry_analytics_data.json"
BATCH_METADATA_FILE="config/batch_metadata.json"
if [ -f "$BATCH_METADATA_FILE" ]; then
  batch_metadata_json=$(cat "$BATCH_METADATA_FILE")
else
  batch_metadata_json='{"batch1":{"dateOfBirth":"","supplier":""},"batch2":{"dateOfBirth":"","supplier":""},"batch3":{"dateOfBirth":"","supplier":""}}'
fi

records_json=$(echo "$response" | jq '
  def n: tonumber? // 0;
  sort_by(.surveydate // ._submission_time // "") |
  map({
    date: (.surveydate // ""),
    b1_trays: (.numbertrays | n),
    b1_eggs: (.numbereggs | n),
    b1_broken: (.numbereggsbroken | n),
    b2_trays: (.numbertraysbatchtwo | n),
    b2_eggs: (.numbereggsbatchtwo | n),
    b2_broken: (.numbereggsbrokenbatchtwo | n),
    b3_trays: (.numbertraysbatchthree | n),
    b3_eggs: (.numbereggsbatchthree | n),
    b3_broken: (.numbereggsbrokenbatchthree | n),
    submittedAt: (._submission_time // "")
  })
')

jq -n \
  --arg today "$today" \
  --arg latest_date "$latest_date" \
  --argjson latest_trays "$latest_trays" \
  --argjson latest_eggs "$latest_eggs" \
  --argjson latest_broken "$latest_eggs_broken" \
  --argjson latest_trays_batch2 "$latest_trays_batch2" \
  --argjson latest_eggs_batch2 "$latest_eggs_batch2" \
  --argjson latest_broken_batch2 "$latest_eggs_broken_batch2" \
  --argjson latest_trays_batch3 "$latest_trays_batch3" \
  --argjson latest_eggs_batch3 "$latest_eggs_batch3" \
  --argjson latest_broken_batch3 "$latest_eggs_broken_batch3" \
  --argjson batch1_daily "$batch1_daily_eggs" \
  --argjson batch2_daily "$batch2_daily_eggs" \
  --argjson batch3_daily "$batch3_daily_eggs" \
  --argjson total_daily "$total_daily_eggs" \
  --arg daily_perc "$laying_percentage_daily" \
  --arg batch1_perc "$laying_percentage_batch1" \
  --arg batch2_perc "$laying_percentage_batch2" \
  --arg batch3_perc "$laying_percentage_batch3" \
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
  --argjson total_trays_b3 "$total_trays_batch3" \
  --argjson total_eggs_b3 "$total_eggs_batch3" \
  --argjson total_broken_b3 "$total_eggs_broken_batch3" \
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
  --argjson records "$records_json" \
'{
  "reportDate": $today,
  "latestEntry": {
    "surveyDate": $latest_date,
    "batch1": { "trays": $latest_trays, "eggs": $latest_eggs, "broken": $latest_broken, "totalEggs": $batch1_daily, "layingPercentage": $batch1_perc },
    "batch2": { "trays": $latest_trays_batch2, "eggs": $latest_eggs_batch2, "broken": $latest_broken_batch2, "totalEggs": $batch2_daily, "layingPercentage": $batch2_perc },
    "batch3": { "trays": $latest_trays_batch3, "eggs": $latest_eggs_batch3, "broken": $latest_broken_batch3, "totalEggs": $batch3_daily, "layingPercentage": $batch3_perc },
    "combined": { "totalEggsEntry": $total_daily, "layingPercentageDaily": $daily_perc },
    "submittedAt": $latest_time
  },
  "overallTotals": {
    "batch1": { "trays": $total_trays_b1, "eggs": $total_eggs_b1, "broken": $total_broken_b1 },
    "batch2": { "trays": $total_trays_b2, "eggs": $total_eggs_b2, "broken": $total_broken_b2 },
    "batch3": { "trays": $total_trays_b3, "eggs": $total_eggs_b3, "broken": $total_broken_b3 },
    "combined": { "totalEggsAllRecords": $total_eggs_all, "totalTraysCalculated": $total_trays_calc, "remainingEggs": $total_eggs_mod }
  },
  "recentTotals": { "sevenDay": $seven_day_total, "thirtyDay": $thirty_day_total },
  "rollingAverages": {
    "yesterday": { "average": $yesterday_avg, "trend": $arrow_yesterday },
    "threeDay": { "average": $avg3, "trend": $arrow3 },
    "sevenDay": { "average": $avg7, "trend": $arrow7 },
    "thirtyDay": { "average": $avg30, "trend": $arrow30 }
  },
  "batchStats": $batchStats,
  "records": $records
}' > "$OUTPUT_FILE"

if [ -s "$OUTPUT_FILE" ]; then
  echo "✓ JSON data successfully written to $OUTPUT_FILE"
else
  echo "✗ ERROR: $OUTPUT_FILE is empty or was not created"
  exit 1
fi
