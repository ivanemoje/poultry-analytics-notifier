"""Format the daily production and sales summary for Slack."""

from .production import BATCH_FIELDS, previous_batch_eggs

INCREASE, SAME, DECREASE = "🟢", "➖", "🔴"
ROLLING_ICONS = {"✅": INCREASE, "🔵": SAME, "❌": DECREASE}
BATCH_METRICS = (
    ("trays", "Trays"),
    ("eggs", "Loose eggs"),
    ("broken", "Broken"),
    ("dead", "Deaths"),
    ("feedGrams", "Feed (g/bird/day)"),
)


def batch_metrics(counts, include_missing=True):
    return " | ".join(
        f"{label} `{counts[key] if counts[key] is not None else '—'}`"
        for key, label in BATCH_METRICS
        if include_missing or counts[key] is not None
    )


def batch_egg_trend(report, batch):
    latest = report["latestEntry"]
    counts = latest[batch]
    if counts["trays"] is None and counts["eggs"] is None:
        return None

    total = counts["totalEggs"]
    previous = previous_batch_eggs(report["records"], batch, latest["surveyDate"])
    if previous is None:
        return f"Eggs: `{total:,}`"

    date, previous_total = previous
    change = total - previous_total
    icon = INCREASE if change > 0 else DECREASE if change < 0 else SAME
    difference = f"{change:+,}" if change else "0"
    return f"{icon} Eggs: `{total:,}` (`{difference}` vs `{date}`)"


def print_summary(report):
    def percent(value):
        return "—" if value is None else f"{value}%"

    latest = report["latestEntry"]
    print(f"*:hatching_chick: Egg Report Summary*\n"
          f"*Reporting for:* `{report['reportDate']}`\n\n"
          f":calendar: Survey Date: `{latest['surveyDate']}`\n")
    offlaid = []
    for batch in BATCH_FIELDS:
        counts = latest[batch]
        status = report["batchStats"].get(batch, {}).get("status") or "unknown"
        if status.lower() == "offlaid":
            offlaid.append((batch, counts))
            continue
        print(f"*Batch {batch[5:]}* ({status})")
        print(batch_metrics(counts))
        trend = batch_egg_trend(report, batch)
        if trend is not None:
            print(trend)
        print(f"Laying % `{percent(counts['layingPercentage'])}`\n")

    combined = latest["combined"]
    totals = report["overallTotals"]["combined"]
    print(f"*Combined*\n:egg: Total Eggs (this entry): `{combined['totalEggsEntry']}`\n"
          f":chart_with_upwards_trend: Laying % (laying batches): "
          f"`{percent(combined['layingPercentageDaily'])}`\n\n"
          f"*Totals (All Records):*\n:egg: Total Eggs: `{totals['totalEggsAllRecords']}`\n"
          f":basket: Trays: `{totals['totalTraysCalculated']}` | "
          f":egg: Remaining Eggs: `{totals['remainingEggs']}`\n\n"
          f"*:calendar: Rolling Averages (combined batches)*")
    for key, label in (("yesterday", "Yesterday"), ("threeDay", "3-Day"),
                       ("sevenDay", "7-Day"), ("thirtyDay", "30-Day")):
        avg = report["rollingAverages"][key]
        print(f"{label} avg: `{avg['average']}` {ROLLING_ICONS[avg['trend']]}")
    print(f"\n:calendar: Data submitted at: `{latest['submittedAt']}`")
    financials = report["financials"]
    sale = financials["latestSale"]
    print("\n*:moneybag: Sales Summary*")
    if sale:
        daily_revenue = sum(row["amount"] for row in financials["salesRecords"]
                            if row["date"] == sale["date"])
        print(f"Revenue on `{sale['date']}`: `{daily_revenue:,} UGX`")
    print(f"Total sales revenue: `{financials['totalRevenue']:,} UGX` "
          f"({len(financials['salesRecords'])} records)")

    if offlaid:
        print("\n*Offlaid batches*")
        for batch, counts in offlaid:
            metrics = batch_metrics(counts, include_missing=False)
            detail = f" — {metrics}" if metrics else ""
            print(f"• Batch {batch[5:]}{detail}")
