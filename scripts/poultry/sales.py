"""Normalize sales and expenses and build their report data."""

import re
from datetime import date, timedelta

from .ona import count, farm_time, field

EXPENSE_CATEGORY = re.compile(
    r"EXPENSE|COST|FEED|VET|VACCINE|TRANSPORT|MAIZE|BRAN|HUSK|LIME|CALCIUM|"
    r"VITAMIN|CHARCOAL|CONCENTRATE|DEWORMER|CHICKS"
)
SALES_PERIODS = {"last7Days": 7, "last30Days": 30, "last90Days": 90}


def recent_revenue(sales):
    through_date = max((row["date"] for row in sales), default="")
    totals = {"throughDate": through_date, **dict.fromkeys(SALES_PERIODS, 0)}
    if through_date:
        end = date.fromisoformat(through_date)
        for period, days in SALES_PERIODS.items():
            start = (end - timedelta(days=days - 1)).isoformat()
            totals[period] = sum(row["amount"] for row in sales if start <= row["date"] <= through_date)
    return totals


def build_financials(sources):
    sales, expenses = [], []
    for source in sources:
        submitted_at = field(source, "_submission_time")
        entry = {
            "date": field(source, "surveydate") or submitted_at[:10],
            "amount": count(source.get("amount")) or 0,
            "payment": field(source, "paymentmode", "payment"),
            "category": field(source, "category"),
            "comments": field(source, "comments"),
            "submittedAt": submitted_at,
        }
        kind = field(source, "type", "category", "subcategory", "expense")
        if EXPENSE_CATEGORY.search(kind.upper()):
            expenses.append({
                **entry,
                "expense": field(source, "expense", "subcategory", "category") or "EXPENSE",
            })
        else:
            sales.append({
                **entry,
                "subcategory": field(source, "subcategory"),
                "trays": count(source.get("numtrays")) or 0,
                "eggs": count(source.get("numeggs")),
                "animals": count(source.get("numanimals")) or 0,
            })

    for entries in (sales, expenses):
        entries.sort(key=lambda row: (row["date"], row["submittedAt"]))
    return {
        "salesRecords": sales,
        "expenseRecords": expenses,
        "totalRevenue": sum(row["amount"] for row in sales),
        "recentRevenue": recent_revenue(sales),
        "latestSale": max(sales, key=lambda row: row["submittedAt"], default=None),
    }


def legacy_sales_report(financials, today, metadata):
    latest = financials["latestSale"] or {}
    return {
        "reportDate": today.isoformat(),
        "latestEntry": {
            "surveyDate": latest.get("date", ""),
            "latestsales": {
                "latestcategory": latest.get("category", ""),
                "subcategory": latest.get("subcategory", ""),
                "paymentmode": latest.get("payment", ""),
                "amount": latest.get("amount", 0),
                "numtrays": latest.get("trays", 0),
                "numanimals": latest.get("animals", 0),
                "comments": latest.get("comments", ""),
            },
            "combined": {"totalAmount": financials["totalRevenue"]},
            "submittedAt": farm_time(latest.get("submittedAt")),
        },
        "batchStats": metadata,
        "salesRecords": financials["salesRecords"],
        "expenseRecords": financials["expenseRecords"],
    }
