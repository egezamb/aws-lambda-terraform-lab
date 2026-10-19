# AWS Lambda Lab — Terraform Edition

![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC?style=flat&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Lambda%20%2B%20EventBridge%20%2B%20API%20Gateway-FF9900?style=flat&logo=amazon-aws&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)
![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?style=flat&logo=github-actions&logoColor=white)

End-to-end Infrastructure-as-Code rebuild of **Lab 10 — Using AWS Lambda** from the *Services and Development Platforms for Cloud Based Applications* course at **WSB Merito Wrocław** (Summer 2025/2026, Wojciech Thomas).

The original lab is a 30+ click-through tour of the AWS Console. This repo reproduces the same architecture as a single `terraform apply`, runs CI on every push, and ships in a state any teammate could pick up and read.

---

## What This Deploys

```
┌─────────────────────────────────────────────────────────────────────┐
│                              Lab 10 (Terraform)                     │
└─────────────────────────────────────────────────────────────────────┘

       Exercise 1                Exercise 2                 Exercise 3
   ────────────────         ──────────────────          ──────────────────

   EventBridge                  Direct test                Function URL
   Scheduler                    event                      (Auth: NONE)
        │                            │                            │
        │ every 2 min                │                            │
        ▼                            ▼                            │
   ┌─────────────┐              ┌─────────────┐                   │
   │ Lambda      │              │ Lambda      │◀──────────────────┤
   │ myFun1      │              │ myFun2      │                   │
   │ ec2_stopper │              │ greeter     │◀──── HTTP API ────┤
   └─────┬───────┘              └─────────────┘                   │
         │                            ▲                           │
         │ stop_instances             │                           │
         ▼                            └────── REST API ───────────┘
   ┌─────────────┐                       (GET + query string
   │  EC2 t3.    │                        + mapping template)
   │  micro      │
   └─────────────┘

   CloudWatch Logs (with 7-day retention) for both Lambdas
```

| Resource | Terraform file | Purpose |
|----------|----------------|---------|
| EC2 `t3.micro` test instance | [`ec2.tf`](./ec2.tf) | Target for the scheduled stopper Lambda |
| Lambda `myFun1` (ec2_stopper) | [`lambda1_ec2_stopper.tf`](./lambda1_ec2_stopper.tf) | Stops the EC2 instance on a schedule |
| EventBridge Scheduler | [`eventbridge.tf`](./eventbridge.tf) | Fires the stopper every 2 minutes |
| Lambda `myFun2` (greeter) | [`lambda2_greeter.tf`](./lambda2_greeter.tf) | Returns `Hello <name>!` from any of 3 invocation shapes |
| Function URL | [`lambda2_greeter.tf`](./lambda2_greeter.tf) | Public HTTPS endpoint, Auth NONE |
| HTTP API Gateway v2 | [`api_gateway.tf`](./api_gateway.tf) | `POST /greet` with JSON body |
| REST API Gateway v1 | [`api_gateway.tf`](./api_gateway.tf) | `GET /myFun2?name=...` with mapping template |
| CloudWatch Log Groups | inline | 7-day log retention for both Lambdas |
| IAM Role | [`providers.tf`](./providers.tf) | References `LabRole` via `data` source (Learner Lab constraint) |

---

## Why Terraform Instead of the Console?

The lab teaches Lambda concepts. Doing it in Terraform teaches the same concepts **plus** the production skill of treating infrastructure as code:

| Manual lab | Terraform version |
|------------|------------------|
| Copy-paste Python code into the web editor | Source in [`lambda/*/lambda_function.py`](./lambda) under version control |
| Hard-code region and instance ID in the function | Environment variables wired by Terraform — function is re-deployable to any region |
| Click through EventBridge wizard | Declarative [`aws_scheduler_schedule`](./eventbridge.tf) with explicit IAM permission |
| Manually deploy REST API after each change | `terraform apply` redeploys when integration changes |
| 30 min of clicks; impossible to reproduce | `terraform apply` ≈ 90 seconds; reproducible on demand |
| Tear-down: 15 clicks across 5 services | `terraform destroy` ≈ 60 seconds |

This is the workflow real cloud teams use. The lab learning objectives (schedules, event-processing, API shapes) are all preserved.

---

## Prerequisites

- **AWS account** — works with the Learner Lab (uses the pre-existing `LabRole`)
- **Terraform** ≥ 1.5 ([install](https://developer.hashicorp.com/terraform/install))
- **AWS CLI** configured (`aws configure` or AWS Learner Lab credentials in `~/.aws/credentials`)
- **Python 3.12+** (only needed if you want to test the Lambda code locally — not required for deployment)

### AWS Learner Lab note

The Learner Lab has two relevant restrictions:

1. **IAM operations are restricted** — you cannot create new IAM roles or policies. This Terraform uses `data.aws_iam_role.lab_role` to reference the existing `LabRole` rather than creating one.

2. **The Function URL answered `403 AccessDeniedException` in the Learner Lab**, although it was created with `AuthType = NONE` and the `FunctionURLAllowPublicAccess` statement. One cause is now known: since October 2025 a new function URL also needs a `lambda:InvokeFunction` statement, and with only `lambda:InvokeFunctionUrl` it answers 403 in any account. This repo now adds that statement (`allow_function_url_invoke`, limited to calls through the URL). Whether the sandbox also blocks public URLs, for example with an SCP, has not been re-tested with both statements. The HTTP API and REST API endpoints are equivalent alternatives and demonstrate the same architectural pattern.

Both constraints are educationally useful — they mirror the kind of organizational guardrails real cloud teams operate under. In a production environment you would create dedicated least-privilege roles per Lambda and explicitly opt into Function URL exposure — see the [Production Hardening](#production-hardening) section.

---

## Deploy

```bash
git clone https://github.com/egezamb/aws-lambda-terraform-lab.git
cd aws-lambda-terraform-lab

terraform init

terraform plan

terraform apply
```

When `apply` finishes you will see outputs like:

```
greeter_function_url        = "https://abc123.lambda-url.us-east-1.on.aws/"
greeter_http_api_endpoint   = "https://xyz.execute-api.us-east-1.amazonaws.com/greet"
greeter_rest_api_endpoint   = "https://qwe.execute-api.us-east-1.amazonaws.com/default/myFun2"

sample_curl_function_url    = "curl -H 'content-type: application/json' -d '{\"name\":\"Ege\"}' https://abc123.lambda-url.us-east-1.on.aws/"
sample_curl_http_api        = "curl -H 'content-type: application/json' -d '{\"name\":\"Ege\"}' https://xyz.execute-api.us-east-1.amazonaws.com/greet"
sample_curl_rest_api        = "curl 'https://qwe.execute-api.us-east-1.amazonaws.com/default/myFun2?name=Ege'"
```

Copy any `sample_curl_*` line and paste it into a terminal — you should see `Hello Ege!`.

### Verify Exercise 1 (EC2 stopper)

```bash
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw ec2_instance_id) \
  --query 'Reservations[0].Instances[0].State.Name'
```

After ~2 minutes (one EventBridge tick) this should print `"stopped"`.

Tail the Lambda logs:

```bash
aws logs tail /aws/lambda/lab10-lambda-myFun1 --follow
```

You should see a JSON summary printed on each invocation.

### Tear down

```bash
terraform destroy
```

Always destroy at the end of your Learner Lab session — sessions are short and resources can be orphaned.

---

## How the Greeter Handles Three Event Shapes

The lab gradually evolves the greeter Lambda to accept three different invocation patterns. Instead of editing the code three times, this Terraform deploys a single version that handles all three safely:

```python
def _extract_name(event):
    if not isinstance(event, dict):
        return "unknown"
    if "name" in event:
        return _clean(event["name"])                  # direct test event

    body = event.get("body")
    if not body:
        return "unknown"

    parsed = json.loads(body) if isinstance(body, str) else body
    return _clean(parsed.get("name"))                 # Function URL / HTTP / REST
```

`_clean` accepts only a non-empty string and cuts it to 64 characters, so a caller cannot make the function echo or log a huge value. The function logs the invocation shape and the name's length, never the event itself: HTTP events carry the caller's IP address and headers. `tests/test_greeter.py` covers the three shapes and bad input, and runs in CI.

`tests/main.tftest.hcl` checks the Terraform itself against a mocked AWS provider, with no account needed: each Lambda logs to its own group with retention, the stopper targets only the lab instance, the schedule invokes the stopper without retries, and every Lambda permission is scoped to its source's ARN. Run it with `terraform init -backend=false && terraform test`.

Same handler, three invocation paths, one Lambda. Saves a redeploy and keeps the code honest.

---

## Lab Learning Objectives → Where Each Is Met

| Lab objective | Where this repo demonstrates it |
|---------------|--------------------------------|
| Configure a scheduled Lambda with EventBridge | [`eventbridge.tf`](./eventbridge.tf) + [`lambda1_ec2_stopper.tf`](./lambda1_ec2_stopper.tf) |
| Verify Lambda execution via CloudWatch | Log groups defined inline; `aws logs tail` command shown above |
| Event-processing Lambda returning structured JSON | [`lambda/greeter/lambda_function.py`](./lambda/greeter/lambda_function.py) |
| Connect Lambda to HTTP API + REST API; understand the difference | Both deployed side-by-side in [`api_gateway.tf`](./api_gateway.tf) — compare the resource counts, the mapping template requirement, and the event shapes |

---

## Checkpoint Answers (for the lab report)

### Exercise 1
1. **Why an IAM role?** Lambda runs without your credentials; it assumes a role to call AWS APIs. The required permission to stop EC2 is `ec2:StopInstances`, scoped to a specific instance ARN in production.
2. **Re-deploying after a trigger fired?** The new code is used on the next invocation; previous executions are not affected. State change is forward-only.
3. **Multi-region stop?** Make a list of `(region, instance_id)` pairs, iterate, and create one `boto3.client('ec2', region_name=r)` per region. Or split into one Lambda per region for blast-radius isolation — see the Reflection section below.

### Exercise 2
1. **`event.get('name', 'unknown')` vs `event['name']`** — `.get()` returns a default if the key is missing; `[]` raises `KeyError`. The difference matters when callers omit fields, which is common with real API traffic.
2. **Why return `{statusCode, headers, body}`?** This is the Lambda Proxy Integration format. API Gateway expects exactly this shape to translate the response into an HTTP reply with status code and headers.
3. **Search in CloudWatch Logs** — filter by the log group `/aws/lambda/lab10-lambda-myFun2` and use the request ID printed in the log header. The function logs `{"source": ..., "name_length": ...}`, not the name or the event, so personal data and caller IPs stay out of the logs.

### Exercise 3
1. **Why did the function code change between Ex 2 and Ex 3?** API Gateway and Function URL deliver the request payload as a JSON string in `event["body"]`, not as top-level keys. The function must parse the body to extract the name.
2. **Purpose of the mapping template?** It transforms the GET request's query-string `name` parameter into the same JSON `body` shape the function already understands. Without it, `event["body"]` would be empty for GET requests, so `name` would resolve to `"unknown"`.
3. **HTTP API vs REST API:**
   - HTTP API is ~70% cheaper and ~60% lower latency
   - REST API supports request transformation, usage plans, API keys, full Swagger/OpenAPI import
   - Choose REST API when you need usage plans, API keys, or complex request/response transformation; HTTP API for everything else
4. **Auth NONE / Security Open** — fine in a sandbox because instances are short-lived. In production: open endpoints are scraped within minutes by bots, Lambda invocations cost money, and you have no audit trail of who called what. Use JWT (Cognito) or IAM auth.

### Reflection — 20 instances across 3 regions

Two approaches:

1. **One Lambda per region, deployed by the same Terraform module**, each triggered by a region-local EventBridge schedule.
   - Pros: blast radius isolated, no cross-region API calls, easier to debug per region
   - Cons: 3× the Terraform resources, 3× the schedules to maintain

2. **One global Lambda with a list of (region, instance_id) pairs**, looping and creating a boto3 client per region.
   - Pros: single function to monitor and update, easier patching
   - Cons: a single failure can affect all regions; cross-region calls add latency; one IAM role with broader permissions

For 20 instances across 3 regions I would go with approach 1 — the blast-radius benefit outweighs the extra Terraform code, and EventBridge schedules per region cost effectively nothing.

---

## Production Hardening

Things this Lab Terraform intentionally does not do because of Learner Lab constraints, that you would do in production:

- **Replace `LabRole` with per-Lambda least-privilege roles**:
  - `ec2_stopper`: only `ec2:StopInstances` on a specific instance ARN
  - `greeter`: only `logs:CreateLogStream` and `logs:PutLogEvents` on its own log group
- **Set Lambda Auth type to `AWS_IAM`** or front the API with a JWT authorizer (Cognito user pool)
- **Restrict EC2 security group** if the test EC2 is used for anything beyond being stopped
- **Add WAF in front of the public APIs.** They are already throttled (`api_rate_limit`, default 5 requests a second, and `api_burst_limit`, default 10), but WAF can block by IP and by request content.
- **Cap the Function URL with reserved concurrency.** The URL itself has no throttle setting, so the API Gateway limits do not cover it.
- **Add X-Ray tracing** for end-to-end request visibility
- **Add a CloudWatch alarm** on Lambda errors > 1% over 5 minutes
- **Use remote Terraform state** in S3 with `use_lockfile = true` instead of local state (Terraform 1.11 made S3 native locking generally available and deprecated the DynamoDB table)
- **Pin the AMI ID** instead of the newest match of the name filter (a reproducibility vs. patching trade-off)

---

## Project Structure

```
aws-lambda-terraform-lab/
├── providers.tf                      # Terraform + AWS provider + LabRole data source
├── variables.tf                      # Input variables (region, runtime, schedule rate, ...)
├── outputs.tf                        # Endpoint URLs + sample curl commands
├── ec2.tf                            # Test EC2 instance
├── lambda1_ec2_stopper.tf            # Exercise 1: scheduled stopper Lambda
├── eventbridge.tf                    # Exercise 1: EventBridge schedule
├── lambda2_greeter.tf                # Exercises 2 + 3: greeter Lambda + Function URL
├── api_gateway.tf                    # Exercise 3: HTTP API + REST API
├── lambda/
│   ├── ec2_stopper/lambda_function.py
│   └── greeter/lambda_function.py
├── tests/test_greeter.py             # pytest for the greeter
├── tests/main.tftest.hcl             # terraform test with a mocked AWS provider
├── .github/workflows/terraform.yml   # CI: fmt + validate + terraform test, Lambda tests, trivy security scan
└── .gitignore
```

---

## Tech Stack

- **Terraform** `>= 1.5` with the `hashicorp/aws` `~> 5.0` provider
- **AWS Lambda** (Python 3.12 runtime)
- **AWS EventBridge Scheduler** (newer than legacy `aws_cloudwatch_event_rule`)
- **AWS API Gateway v2** (HTTP API) and v1 (REST API)
- **AWS CloudWatch Logs**
- **GitHub Actions** for CI

---

## Author

**Ege Zambelli** — 3rd-year Software Development student at WSB Merito Wrocław, focusing on cloud engineering and DevOps.

- GitHub: [@egezamb](https://github.com/egezamb)
- Related projects:
  - [aws-terraform-starter](https://github.com/egezamb/aws-terraform-starter) — VPC + EC2 + S3 Terraform starter
  - [calculator-pytest-cicd](https://github.com/egezamb/calculator-pytest-cicd) — Python + pytest + GitHub Actions CI
  - [sbatools](https://github.com/egezamb/sbatools) — Git Flow + release automation

---

## License

Educational work for WSB Merito Wrocław. Free to use, modify, and learn from. Attribution appreciated.
