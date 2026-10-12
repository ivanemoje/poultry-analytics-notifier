"""Build the dashboard data and Slack report from the Ona submissions on stdin."""

import json
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from tempfile import NamedTemporaryFile

# The Ona form uses different suffixes for egg, mortality and feed fields.
BATCH_FIELDS = {
    "batch1": ("", "", ""),
    "batch2": ("batchtwo", "two", "two"),
    "batch3": ("batchthree", "three", "three"),
    "batch4": ("batchfour", "batchfour", "four"),
    "batch5": ("batchfive", "batchfive", "five"),
}
LAYING_STATUSES = {"active", "laying"}
WINDOWS = {"threeDay": 3, "sevenDay": 7, "thirtyDay": 30}
FARM_TIMEZONE = timezone(timedelta(hours=3))


def count(value):
    if value is None or str(value).strip().lower() in {"", "n/a"}:
        return None
    return int(value)


def normalize_record(source):
    submitted_at = source.get("_submission_time", "")
    record = {
        "date": source.get("surveydate") or submitted_at[:10],
        "submittedAt": submitted_at,
    }
    if source.get("category"):
        record["category"] = source["category"].lower()
    for batch, (eggs, dead, feed) in BATCH_FIELDS.items():
        prefix = "b" + batch[5:]
        record.update({
            f"{prefix}_trays": count(source.get("numbertrays" + eggs)),
            f"{prefix}_eggs": count(source.get("numbereggs" + eggs)),
            f"{prefix}_broken": count(source.get("numbereggsbroken" + eggs)),
            f"{prefix}_dead": count(source.get("numberdeadbirds" + dead)),
            f"{prefix}_feedGrams": count(source.get("numberdailygrams" + feed)),
        })
    return record


def batch_counts(record, batch):
    prefix = "b" + batch[5:]
    return {field: record.get(f"{prefix}_{field}")
            for field in ("trays", "eggs", "broken", "dead", "feedGrams")}


def eggs_in(counts):
    return 30 * (counts["trays"] or 0) + (counts["eggs"] or 0)


def laying_percentage(eggs, birds):
    return f"{100 * eggs / birds:.1f}" if birds else None


def build_report(sources, metadata, today, previous_records=()):
    records = sorted(map(normalize_record, sources), key=lambda row: (row["date"], row["submittedAt"]))
    # The current form can omit Batch 1 fields from older submissions.
    if metadata.get("batch1", {}).get("status") == "offlaid":
        archive = {row["submittedAt"]: row for row in previous_records if row.get("submittedAt")}
        for row in records:
            saved = archive.get(row["submittedAt"], {})
            for field in ("b1_trays", "b1_eggs", "b1_broken"):
                if row[field] is None:
                    row[field] = saved.get(field)
    production = [row for row in records if row["date"] and row.get("category") != "feeds"]
    latest = max(production, key=lambda row: row["submittedAt"], default={})
    batches = {batch: metadata[batch] for batch in BATCH_FIELDS if batch in metadata}
    laying_birds = {
        batch: int(config.get("currentBirds") or 0)
        for batch, config in batches.items()
        if (config.get("status") or "").lower() in LAYING_STATUSES
    }

    latest_batches = {}
    overall_batches = {}
    for batch in BATCH_FIELDS:
        counts = batch_counts(latest, batch)
        latest_batches[batch] = {
            **counts,
            "totalEggs": eggs_in(counts),
            "layingPercentage": laying_percentage(eggs_in(counts), laying_birds.get(batch))
            if counts["trays"] is not None or counts["eggs"] is not None else None,
        }
        all_counts = [batch_counts(row, batch) for row in production]
        overall_batches[batch] = {
            field: sum(row[field] or 0 for row in all_counts)
            for field in ("trays", "eggs", "broken", "dead")
        }

    dated_totals = [
        (row["date"], sum(eggs_in(batch_counts(row, batch)) for batch in BATCH_FIELDS))
        for row in production
    ]
    total = sum(eggs for _, eggs in dated_totals)
    total_trays, remaining_eggs = divmod(total, 30)
    latest_total = sum(row["totalEggs"] for row in latest_batches.values())
    reporting_layers = [batch for batch in laying_birds
                        if latest_batches[batch]["layingPercentage"] is not None]
    laying_eggs = sum(latest_batches[batch]["totalEggs"] for batch in reporting_layers)
    current_birds = sum(laying_birds[batch] for batch in reporting_layers)

    submitted = latest.get("submittedAt")
    submitted_at = ""
    if submitted:
        timestamp = datetime.fromisoformat(submitted.replace("Z", "+00:00"))
        if timestamp.tzinfo is None:
            timestamp = timestamp.replace(tzinfo=timezone.utc)
        submitted_at = timestamp.astimezone(FARM_TIMEZONE).strftime("%Y-%m-%d %H:%M")

    today_values = [eggs for day, eggs in dated_totals if day == today.isoformat()]
    yesterday = (today - timedelta(days=1)).isoformat()
    windows = {"yesterday": [eggs for day, eggs in dated_totals if day == yesterday]}
    for name, days in WINDOWS.items():
        cutoff = (today - timedelta(days=days)).isoformat()
        windows[name] = [eggs for day, eggs in dated_totals if cutoff < day <= today.isoformat()]

    def average(values):
        return sum(values) // len(values) if values else 0

    today_avg = average(today_values)
    rolling = {}
    for name, values in windows.items():
        avg = average(values)
        trend = "✅" if today_avg > avg else "❌" if today_avg < avg else "🔵"
        rolling[name] = {"average": avg, "trend": trend}

    return {
        "reportDate": today.isoformat(),
        "latestEntry": {
            "surveyDate": latest.get("date", ""),
            **latest_batches,
            "combined": {
                "totalEggsEntry": latest_total,
                "layingPercentageDaily": laying_percentage(laying_eggs, current_birds),
            },
            "submittedAt": submitted_at,
        },
        "overallTotals": {
            **overall_batches,
            "combined": {
                "totalEggsAllRecords": total,
                "totalTraysCalculated": total_trays,
                "remainingEggs": remaining_eggs,
            },
        },
        "recentTotals": {"sevenDay": sum(windows["sevenDay"]), "thirtyDay": sum(windows["thirtyDay"])},
        "rollingAverages": rolling,
        "batchStats": metadata,
        "records": records,
    }


def print_summary(report):
    def percent(value):
        return "—" if value is None else f"{value}%"

    latest = report["latestEntry"]
    print(f"*:hatching_chick: Egg Report Summary*\n"
          f"*Reporting for:* `{report['reportDate']}`\n\n"
          f":calendar: Survey Date: `{latest['surveyDate']}`\n")
    for batch in BATCH_FIELDS:
        counts = latest[batch]
        status = report["batchStats"].get(batch, {}).get("status", "unknown")
        metrics = ["Trays", "Loose eggs", "Broken", "Deaths", "Feed (g/bird/day)"]
        values = [counts[key] for key in ("trays", "eggs", "broken", "dead", "feedGrams")]
        print(f"*Batch {batch[5:]}* ({status})")
        print(" | ".join(f"{label} `{value if value is not None else '—'}`"
                         for label, value in zip(metrics, values)))
        print(f":chart_with_upwards_trend: Laying % `{percent(counts['layingPercentage'])}`\n")

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
        print(f"{label} avg: `{avg['average']}` {avg['trend']}")
    print(f"\n:calendar: Data submitted at: `{latest['submittedAt']}`")


if __name__ == "__main__":
    sources = json.load(sys.stdin)
    if not isinstance(sources, list) or not sources:
        sys.exit("Ona returned no submission records")
    metadata = json.loads(Path("config/batch_metadata.json").read_text())
    destination = Path("poultry_analytics_data.json")
    previous = json.loads(destination.read_text()).get("records", []) if destination.exists() else []
    report = build_report(sources, metadata, datetime.now(timezone.utc).date(), previous)
    with NamedTemporaryFile(mode="w", dir=destination.parent, encoding="utf-8", delete=False) as temporary:
        path = Path(temporary.name)
        try:
            json.dump(report, temporary, indent=2, ensure_ascii=False)
            temporary.write("\n")
            temporary.close()
            path.replace(destination)
        finally:
            path.unlink(missing_ok=True)
    print_summary(report)
