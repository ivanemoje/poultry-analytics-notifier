"""Shared value and timestamp parsing for Ona form records."""

from datetime import datetime, timedelta, timezone

FARM_TIMEZONE = timezone(timedelta(hours=3))


def count(value):
    if value is None or str(value).strip().lower() in {"", "n/a"}:
        return None
    return int(value)


def field(source, *names):
    for name in names:
        value = source.get(name)
        if value is not None and str(value).strip().lower() not in {"", "n/a"}:
            return value
    return ""


def farm_time(submitted):
    if not submitted:
        return ""
    timestamp = datetime.fromisoformat(submitted.replace("Z", "+00:00"))
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=timezone.utc)
    return timestamp.astimezone(FARM_TIMEZONE).strftime("%Y-%m-%d %H:%M")
