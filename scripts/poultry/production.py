"""Normalize egg submissions and calculate flock and production metrics."""

from datetime import timedelta

from .ona import count, farm_time

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


def previous_batch_eggs(records, batch, survey_date):
    for row in reversed(records):
        if not row["date"] or row["date"] >= survey_date or row.get("category") == "feeds":
            continue
        counts = batch_counts(row, batch)
        if counts["trays"] is not None or counts["eggs"] is not None:
            return row["date"], eggs_in(counts)
    return None


def laying_percentage(eggs, birds):
    return f"{100 * eggs / birds:.1f}" if birds else None


def production_records(sources, metadata, previous_records):
    records = sorted(map(normalize_record, sources), key=lambda row: (row["date"], row["submittedAt"]))
    # The current form can omit Batch 1 fields from older submissions.
    if metadata.get("batch1", {}).get("status") == "offlaid":
        archive = {row["submittedAt"]: row for row in previous_records if row.get("submittedAt")}
        for row in records:
            saved = archive.get(row["submittedAt"], {})
            for field in ("b1_trays", "b1_eggs", "b1_broken"):
                if row[field] is None:
                    row[field] = saved.get(field)
    return records


def summarize_latest(latest, metadata):
    laying_birds = {
        batch: int(metadata[batch].get("currentBirds") or 0)
        for batch in BATCH_FIELDS
        if batch in metadata and (metadata[batch].get("status") or "").lower() in LAYING_STATUSES
    }

    latest_batches = {}
    for batch in BATCH_FIELDS:
        counts = batch_counts(latest, batch)
        total = eggs_in(counts)
        reported = counts["trays"] is not None or counts["eggs"] is not None
        latest_batches[batch] = {
            **counts,
            "totalEggs": total,
            "layingPercentage": laying_percentage(total, laying_birds.get(batch)) if reported else None,
        }

    reporting_layers = [batch for batch in laying_birds
                        if latest_batches[batch]["layingPercentage"] is not None]
    laying_eggs = sum(latest_batches[batch]["totalEggs"] for batch in reporting_layers)
    current_birds = sum(laying_birds[batch] for batch in reporting_layers)
    return {
        "surveyDate": latest.get("date", ""),
        **latest_batches,
        "combined": {
            "totalEggsEntry": sum(row["totalEggs"] for row in latest_batches.values()),
            "layingPercentageDaily": laying_percentage(laying_eggs, current_birds),
        },
        "submittedAt": farm_time(latest.get("submittedAt")),
    }


def summarize_totals(production, total):
    totals = {}
    for batch in BATCH_FIELDS:
        all_counts = [batch_counts(row, batch) for row in production]
        totals[batch] = {
            field: sum(row[field] or 0 for row in all_counts)
            for field in ("trays", "eggs", "broken", "dead")
        }
    trays, remainder = divmod(total, 30)
    totals["combined"] = {
        "totalEggsAllRecords": total,
        "totalTraysCalculated": trays,
        "remainingEggs": remainder,
    }
    return totals


def summarize_recent(dated_totals, today):
    today_iso = today.isoformat()
    today_values = [eggs for day, eggs in dated_totals if day == today_iso]
    yesterday = (today - timedelta(days=1)).isoformat()
    windows = {"yesterday": [eggs for day, eggs in dated_totals if day == yesterday]}
    for name, days in WINDOWS.items():
        cutoff = (today - timedelta(days=days)).isoformat()
        windows[name] = [eggs for day, eggs in dated_totals if cutoff < day <= today_iso]

    def average(values):
        return sum(values) // len(values) if values else 0

    today_avg = average(today_values)
    rolling = {}
    for name, values in windows.items():
        avg = average(values)
        trend = "✅" if today_avg > avg else "❌" if today_avg < avg else "🔵"
        rolling[name] = {"average": avg, "trend": trend}
    recent = {"sevenDay": sum(windows["sevenDay"]), "thirtyDay": sum(windows["thirtyDay"])}
    return recent, rolling


def build_report(sources, metadata, today, previous_records=()):
    records = production_records(sources, metadata, previous_records)
    production = [row for row in records if row["date"] and row.get("category") != "feeds"]
    latest = max(production, key=lambda row: row["submittedAt"], default={})
    dated_totals = [
        (row["date"], sum(eggs_in(batch_counts(row, batch)) for batch in BATCH_FIELDS))
        for row in production
    ]
    recent, rolling = summarize_recent(dated_totals, today)

    return {
        "reportDate": today.isoformat(),
        "latestEntry": summarize_latest(latest, metadata),
        "overallTotals": summarize_totals(production, sum(eggs for _, eggs in dated_totals)),
        "recentTotals": recent,
        "rollingAverages": rolling,
        "batchStats": metadata,
        "records": records,
    }
