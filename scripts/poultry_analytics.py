"""Read Ona responses from stdin and publish the poultry analytics reports."""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from stat import S_IMODE
from tempfile import NamedTemporaryFile

from poultry.production import build_report
from poultry.sales import build_financials, legacy_sales_report
from poultry.slack import print_summary


def write_report(destination, report):
    mode = S_IMODE(destination.stat().st_mode) if destination.exists() else 0o644
    with NamedTemporaryFile(mode="w", dir=destination.parent, encoding="utf-8", delete=False) as temporary:
        path = Path(temporary.name)
        try:
            json.dump(report, temporary, indent=2, ensure_ascii=False)
            temporary.write("\n")
            temporary.close()
            path.chmod(mode)
            path.replace(destination)
        finally:
            path.unlink(missing_ok=True)


def main():
    forms = json.load(sys.stdin)
    for name in ("production", "sales"):
        if not isinstance(forms.get(name), list) or not forms[name]:
            sys.exit(f"Ona returned no {name} submission records")

    today = datetime.now(timezone.utc).date()
    metadata = json.loads(Path("config/batch_metadata.json").read_text())
    sales_metadata_file = Path("config/batch_sales_metadata.json")
    sales_metadata = json.loads(sales_metadata_file.read_text()) if sales_metadata_file.exists() else {}
    destination = Path("poultry_analytics_data.json")
    previous = json.loads(destination.read_text()).get("records", []) if destination.exists() else []
    report = build_report(forms["production"], metadata, today, previous)
    financials = build_financials(forms["sales"])
    report["financials"] = financials
    sales_report = legacy_sales_report(financials, today, sales_metadata)
    write_report(Path("poultry_sales_data.json"), sales_report)
    write_report(destination, report)
    print_summary(report)


if __name__ == "__main__":
    main()
