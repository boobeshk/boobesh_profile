"""Prints last month's AWS cost grouped by a cost-allocation tag (default: Project).

Usage:
    python cost_report.py            # group by Project
    python cost_report.py Team       # group by another tag

The tag must be activated as a cost-allocation tag in the Billing console first.
"""

import datetime as dt
import sys

import boto3


def last_full_month():
    first_this_month = dt.date.today().replace(day=1)
    first_last_month = (first_this_month - dt.timedelta(days=1)).replace(day=1)
    return first_last_month.isoformat(), first_this_month.isoformat()


def main(tag_key):
    start, end = last_full_month()
    result = boto3.client("ce").get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "TAG", "Key": tag_key}],
    )

    rows = []
    for group in result["ResultsByTime"][0]["Groups"]:
        # Keys look like "Project$checkout"; an empty value means untagged spend.
        value = group["Keys"][0].split("$", 1)[1] or "(untagged)"
        amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
        rows.append((value, amount))

    rows.sort(key=lambda r: r[1], reverse=True)
    total = sum(amount for _, amount in rows)

    print(f"AWS cost by tag '{tag_key}', {start} to {end}")
    for value, amount in rows:
        share = (amount / total * 100) if total else 0
        print(f"  {value:<30} ${amount:>10,.2f}  {share:5.1f}%")
    print(f"  {'TOTAL':<30} ${total:>10,.2f}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Project")
