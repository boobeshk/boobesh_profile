# Architecture: AWS FinOps Guardrails

## Components

| Component | Choice | Why |
|---|---|---|
| Budget | AWS Budgets, monthly COST budget | Two alerts: forecast at 80% (time to act) and actual at 100% (overspent) |
| Anomalies | Cost Anomaly Detection, per-service monitor | Catches spikes a fixed budget misses, such as a runaway NAT gateway |
| Scheduler | Lambda + two EventBridge cron rules | Serverless and cheap; one function handles both actions |
| Opt-in | `Schedule=office-hours` tag | Teams choose which instances follow the schedule |
| Reporting | Cost Explorer `GetCostAndUsage` grouped by tag | Shows who spends what, and how much spend is untagged |

## Scheduler flow

1. EventBridge fires at 14:30 UTC (20:00 IST) with `{"action": "stop"}`.
2. The Lambda lists **running** instances tagged `Schedule=office-hours` (paginated).
3. It calls `StopInstances` on them. The IAM condition `aws:ResourceTag/Schedule = office-hours` means even a
   bug can't stop an untagged instance.
4. At 03:00 UTC (08:30 IST) the same function runs with `start` against **stopped** tagged instances.

## Design decisions

- **Opt-in, not opt-out.** Stopping production by mistake is worse than missing a saving, so instances must be tagged.
- **Guardrail in IAM, not only in code.** The tag condition is enforced by AWS itself.
- **Forecast alert before actual.** An alert at 100% actual spend comes too late; the forecast alert gives days to react.
- **Untagged spend is shown, not hidden.** The report lists `(untagged)` as its own row, which drives better tagging.

## Savings estimate

An instance running 08:30–20:00 on weekdays runs 57.5 of 168 hours a week, so it is off **about 66%** of the time.
For a `t3.large` in ap-south-1, that is roughly $40 saved per instance per month.

## Production hardening (next steps)

- Deliver alerts to Slack or Teams through SNS and AWS Chatbot instead of email.
- Add holiday calendars and per-team schedules (for example a `Schedule=team-a` tag mapped to its own cron).
- Use AWS Organizations so budgets and anomaly monitors cover every account.
- Add RDS and Auto Scaling group support to the scheduler.
