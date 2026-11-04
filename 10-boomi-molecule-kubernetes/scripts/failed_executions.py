"""Lists Boomi process executions that ended in ERROR during the last N hours.

Exits with status 1 when failures exist, so it can run as a scheduled monitoring job.

Usage:
    python failed_executions.py --hours 24
"""

import argparse
import datetime as dt
import sys

from boomi_api import BoomiClient


def query_failures(client, hours):
    now = dt.datetime.now(dt.timezone.utc)
    since = now - dt.timedelta(hours=hours)
    fmt = "%Y-%m-%dT%H:%M:%SZ"
    body = {
        "QueryFilter": {
            "expression": {
                "operator": "and",
                "nestedExpression": [
                    {"property": "status", "operator": "EQUALS", "argument": ["ERROR"]},
                    {
                        "property": "executionTime",
                        "operator": "BETWEEN",
                        "argument": [since.strftime(fmt), now.strftime(fmt)],
                    },
                ],
            }
        }
    }

    page = client.post("ExecutionRecord/query", body)
    records = list(page.get("result", []))
    # Results are paged; follow queryToken until there are no more pages.
    while page.get("queryToken"):
        page = client.post("ExecutionRecord/queryMore", page["queryToken"])
        records.extend(page.get("result", []))
    return records


def main():
    parser = argparse.ArgumentParser(description="List failed Boomi executions.")
    parser.add_argument("--hours", type=int, default=24, help="Look-back window in hours (default 24)")
    args = parser.parse_args()

    failures = query_failures(BoomiClient(), args.hours)
    if not failures:
        print(f"No failed executions in the last {args.hours} hours.")
        return

    print(f"{len(failures)} failed execution(s) in the last {args.hours} hours:")
    for record in failures:
        message = (record.get("message") or "").replace("\n", " ")[:120]
        print(f"  {record.get('executionTime')}  {record.get('processName')}  {record.get('executionId')}  {message}")
    sys.exit(1)


if __name__ == "__main__":
    main()
