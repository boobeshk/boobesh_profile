# Architecture: AWS Serverless API

## Components

| Component | Choice | Why |
|---|---|---|
| Entry point | API Gateway HTTP API, `$default` stage | Cheaper and faster than REST API for simple proxying |
| Compute | One Lambda, Python 3.12, 256 MB | Simple routing table; cold starts stay small |
| Data | DynamoDB on-demand, key `id` | No capacity planning; scales with traffic |
| Backup | Point-in-time recovery | Restore to any second in the last 35 days |
| Logs | CloudWatch log group, 14 days | Created by Terraform so retention is enforced |
| Tracing | X-Ray active tracing | Latency breakdown per request |

## Request flow

1. The client calls the HTTP API. The stage throttles to 20 requests/second (burst 50).
2. API Gateway invokes the Lambda with a v2.0 payload; `routeKey` (for example `GET /items/{id}`) selects the handler.
3. The handler validates input and reads or writes DynamoDB.
4. The response returns as JSON with the right status code (201, 400, 404 and so on).

## Design decisions

- **One function, routing table inside.** For a small API this is easier to deploy and observe than one function per
  route. Split into separate functions when routes need different memory, timeouts or permissions.
- **Log group managed by Terraform.** Otherwise Lambda creates it on first run with no retention, and logs are kept
  (and billed) forever.
- **`depends_on` the IAM policy.** Stops the first invocation from failing before permissions exist.
- **Scan limited to 100 items.** Keeps the list call cheap. Production would paginate with `LastEvaluatedKey`.

## Security

- The IAM policy is scoped to one table ARN and one log group. No wildcards except X-Ray, which doesn't support
  resource-level permissions.
- DynamoDB encryption at rest is enabled.
- Input is validated (`name` required, body must be JSON) before anything is written.

## Production hardening (next steps)

- Add authentication: a JWT authorizer (Cognito or another OIDC provider) on the routes.
- Add a custom domain with an ACM certificate, and AWS WAF.
- Add CloudWatch alarms on Lambda errors, throttles and p99 duration.
- Store Terraform state remotely and deploy through CI.
