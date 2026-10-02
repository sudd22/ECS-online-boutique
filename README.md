<h1 align="center"> ECS Online Boutique — Modular Monolith on AWS</h1>

<p align="center">
  <strong>A FastAPI online boutique deployed as a modular monolith on AWS.</strong><br/>
  Terraform manages the infrastructure, while GitHub Actions builds, scans and deploys the container.
</p>

<p align="center">
  Browse the catalogue, sign in, create an order and run the payment and notification flows through one application.
</p>

---

## Architecture

<p align="center">
  <em>Main architecture diagram will be added here.</em><br/>
  <sub>Add the main architecture image to <code>Assets/</code> when it is ready.</sub>
</p>

The application runs in **`eu-west-2` (London)**. The FastAPI service runs on ECS Fargate in private subnets. An Application Load Balancer and AWS WAF handle public traffic, while RDS PostgreSQL stores the application data.

The application is one deployable service with five internal modules:

- Auth
- Product
- Order
- Payment
- Notification

Each module owns its tables logically. Modules do not join directly to another module's tables. They use public service functions for synchronous work and SQS for asynchronous events.

---

## Why this project

This project applies cloud and platform engineering practices to a small e-commerce application:

- FastAPI and SQLAlchemy provide the application and data layer
- Domain modules keep the monolith organised without the cost of separate services
- ECS Fargate runs the container without server management
- RDS PostgreSQL stores the catalogue, users, orders, payments and notifications
- SQS and a dead-letter queue handle background notification work
- Terraform defines the AWS infrastructure
- GitHub Actions uses OIDC instead of long-lived AWS access keys
- AWS FIS, CloudWatch, DevOps Agent and Slack demonstrate approval-based remediation

The application also includes a small storefront at `/store`, served by FastAPI from the same container as the API.

<p align="center">
  <video src="Assets/webapp.webm" controls muted playsinline width="900">
    <a href="Assets/webapp.webm">Watch the storefront recording</a>
  </video>
  <br/>
  <em>Storefront and API demonstration</em>
</p>

---

## How a checkout works

1. Open `/store`. The page loads the catalogue from `GET /products`.
2. Add products to the client-side bag.
3. Sign in through the storefront or `POST /auth/login`.
4. Submit the bag to `POST /orders` with the bearer token.
5. The order module asks the product module for the selected products, checks stock, calculates the total and creates the order.
6. Call `POST /payments/process` to run the payment simulator.
7. A successful payment is saved and publishes a `payment.completed` event to SQS when a queue is configured.
8. The notification consumer reads the event and records the notification.

The payment service is deliberately simulated:

- Most amounts return a successful payment after a short delay.
- An amount of **`66.60`** returns HTTP `402` to provide a repeatable failure path.
- An event with `order_id` **`999`** fails in the notification consumer so SQS retries it and eventually sends it to the dead-letter queue.

---

## Infrastructure highlights

### Network and edge

- VPC with two public and two private subnets across two Availability Zones
- ECS tasks, RDS and the notification Lambda run in private subnets
- Public Application Load Balancer forwards traffic to port `8000`
- AWS WAF rate-limits requests to 100 per IP
- NAT Gateway is optional and controlled with `deploy_nat_gateway`
- Production adds Route 53 records and an ACM certificate for `seudd.online`

### Application platform

- ECS Fargate service named `dev-b2b-monolith-service` in development
- Production runs with two desired tasks; development uses one
- RDS PostgreSQL stores application data
- RDS manages the database master password in Secrets Manager
- SQS notifications queue uses a dead-letter queue after three failed receives
- The notification consumer is a container-image Lambda using the same ECR image as the application

### Container and delivery

- Python 3.11 slim multi-stage image
- Dependencies are built as wheels before the runtime image is assembled
- The container runs as a non-root user
- Docker health checks call `/health`
- ECR stores the application image and scans images on push
- The same image supports ECS with Uvicorn and Lambda with `awslambdaric`

---

## Scalability and resilience

The design keeps the application simple while allowing the main components to scale independently:

- Fargate can run more than one application task.
- The ALB distributes requests between healthy tasks.
- RDS provides the shared relational data store.
- SQS separates notification processing from the checkout request.
- Lambda consumes notifications without a permanently running worker.
- The notification dead-letter queue keeps failed messages for investigation.

The current implementation is sized as a portfolio and demonstration system rather than a high-volume retail platform. The production environment uses two Fargate tasks, while development is smaller and can be scaled down between sessions. The RDS module defaults to a single-AZ instance unless its settings are changed.

---

## CI/CD — four workflows with OIDC

GitHub Actions authenticates to AWS through GitHub's OIDC provider. No long-lived AWS access keys are required in the repository.

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `build-and-push.yml` | Push to `main` or manual run | Builds the image, runs Trivy, pushes SHA and `latest` tags to ECR, then forces an ECS deployment |
| `terraform-plan.yml` | Pull requests changing Terraform or manual run | Runs Terraform formatting, validation, TFLint, Checkov and a plan |
| `terraform-apply.yml` | Terraform changes on `main` or manual run | Applies the selected environment with Terraform |
| `terraform-destroy.yml` | Manual run | Destroys the selected Terraform environment |

The production safeguards require:

- `apply-prod` when manually applying the production environment
- `destroy-prod` when manually destroying the production environment

Trivy and Checkov are present as part of the pipeline. Review the workflow settings before treating either scan as a release gate.

### Pipeline evidence

<p align="center">
  <img src="Assets/cicd.png" alt="GitHub Actions workflows" width="900" />
</p>

---

## Security model

| Protection | How it works |
|------------|--------------|
| Private application tasks | ECS tasks do not receive public IP addresses and accept application traffic from the ALB |
| Private database | RDS accepts PostgreSQL traffic from the ECS and notification Lambda security groups |
| Edge rate limiting | AWS WAF blocks an IP after the configured request limit |
| Temporary CI credentials | GitHub Actions assumes AWS roles through OIDC |
| Secret storage | RDS manages the master password in Secrets Manager |
| Non-root container | The application image runs as UID `10001` |
| Scoped remediation | The remediation Lambda is limited to updating the configured ECS service |

This is a demonstration application. Payment processing is simulated, JWTs use application configuration, and the authentication, payment and notification routes should be reviewed before using the project for real customer data or payments.

Do not commit `.env` files, Terraform state, access keys, database passwords, webhook URLs or API keys. Use environment variables, GitHub secrets and Secrets Manager for local and deployed credentials.

---

## Observability and AIOps

The ECS task includes an AWS Distro for OpenTelemetry (ADOT) sidecar. The FastAPI application is started with OpenTelemetry auto-instrumentation and sends telemetry to the sidecar. CloudWatch receives logs and metrics, while X-Ray receives traces.

The task and infrastructure also provide:

- `/health` for container and ALB health checks
- Seven-day CloudWatch log retention
- CloudWatch alarms for the development ALB 5xx path
- EventBridge forwarding for alarm events
- DevOps Agent ingestion through a webhook
- Slack approval through AWS Chatbot
- A remediation Lambda that forces a new ECS deployment

<p align="center">
  <em>AIOps flow diagram will be added here.</em><br/>
  <sub>Add the AIOps diagram to <code>Assets/</code> when it is ready.</sub>
</p>

The intended demonstration is:

`FIS → CloudWatch alarm → EventBridge → DevOps Agent → Slack approval → remediation Lambda → ECS deployment`

AWS FIS blackholes outbound TCP port `5432` on one ECS task for ten minutes. The database connection fails, but the telemetry path on port `443` remains available. After approval in Slack, the remediation Lambda forces a new deployment and ECS starts a replacement task with a new network interface.

### AIOps evidence

<p align="center">
  <img src="Assets/experiment%20profile.png" alt="AWS FIS experiment profile" width="900" />
</p>

<p align="center">
  <img src="Assets/aws%20devops%20agent%20incident%20analysis.png" alt="AWS DevOps Agent incident analysis" width="900" />
</p>

<p align="center">
  <img src="Assets/fis%20fix%20lambda%20funciton%20in%20slack.png" alt="Slack remediation approval" width="900" />
</p>

<p align="center">
  <img src="Assets/cloudwatch%205xx%20alarm%20after%20fis%20is%20fixed.png" alt="CloudWatch alarm recovery" width="900" />
</p>

Further screenshots: [FIS experiment start](Assets/experiment%20init.png) and [successful ECS redeployment](Assets/Screenshot%20from%202026-07-27%2002-09-40.png).

The AIOps path requires account-specific DevOps Agent webhook settings and Slack workspace and channel identifiers.

---

## Run locally (no AWS required)

### Native Python setup

Requirements: Python 3.11 and pip.

```bash
git clone https://github.com/sudd22/ECS-online-boutique.git
cd ECS-online-boutique

python3.11 -m venv .venv
source .venv/bin/activate
pip install -r dockerfiles/requirements.txt

export ENVIRONMENT=local
export DATABASE_URL=sqlite:///./local_b2b.db
uvicorn app.main:app --reload --port 8000
```

Open:

- Storefront: [http://localhost:8000/store](http://localhost:8000/store)
- API documentation: [http://localhost:8000/docs](http://localhost:8000/docs)
- Health check: [http://localhost:8000/health](http://localhost:8000/health)
- Product catalogue: [http://localhost:8000/products](http://localhost:8000/products)

Local startup creates the database tables and syncs the sample catalogue. The seeded development account is:

```text
Email: customer@shop.com
Password: password123
```

### Docker Compose

The intended command is:

```bash
docker compose -f dockerfiles/compose.yml up --build
```

The current Compose file points at `Dockerfile` while the file is stored in `dockerfiles/Dockerfile`. If the image build cannot find the Dockerfile, set the Compose build entry to:

```yaml
dockerfile: dockerfiles/Dockerfile
```

The Compose database uses PostgreSQL 15 and persists data in the `postgres_local_data` volume. OpenTelemetry is disabled locally because the ADOT sidecar is only used in ECS.

### Quick API tour

Get a token with the OAuth2 password flow:

```bash
curl -X POST http://localhost:8000/auth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=customer@shop.com&password=password123"
```

List products:

```bash
curl http://localhost:8000/products
```

Create an order with the returned token:

```bash
curl -X POST http://localhost:8000/orders \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"product_id":1,"quantity":1}]}'
```

Run the payment simulator:

```bash
curl -X POST http://localhost:8000/payments/process \
  -H "Content-Type: application/json" \
  -d '{"order_id":1,"amount":"89.00"}'
```

Use `"amount":"66.60"` to exercise the simulated HTTP `402` response.

---

## Repository layout

```text
├── .github/workflows/          # Build, Terraform plan/apply and destroy workflows
├── app/                        # FastAPI modular monolith
│   ├── core/                   # Database, dependencies and seed data
│   ├── modules/
│   │   ├── auth/               # Users, tenants and JWT login
│   │   ├── product/            # Public product catalogue
│   │   ├── order/              # Orders and order items
│   │   ├── payment/            # Payment simulator and SQS publisher
│   │   └── notification/       # Notification records and SQS consumer
│   ├── static/                 # Storefront served at /store
│   ├── config.py               # Environment-based settings
│   └── main.py                 # Application entrypoint and routes
├── Assets/                     # Screenshots and application recording
├── dockerfiles/
│   ├── Dockerfile              # Multi-stage application image
│   ├── compose.yml             # Local PostgreSQL and web services
│   └── requirements.txt        # Python dependencies
├── terraform/
│   ├── persistent/             # State, ECR, KMS and GitHub OIDC resources
│   ├── modules/                # Reusable AWS infrastructure modules
│   └── environments/
│       ├── dev/                # Development environment
│       └── prod/               # Production environment
├── .env.example
├── .gitignore
└── .trivyignore
```

---

## Deploy model

### First time — create the persistent resources

The persistent Terraform layer creates the state bucket, state lock table, KMS key, ECR repository and GitHub OIDC roles. Review the backend and account-specific values before applying it.

```bash
cd terraform/persistent
terraform init
terraform plan
terraform apply
```

### Deploy an environment

The development and production environments use separate Terraform state keys. Both use `eu-west-2`.

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

For production:

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

The production environment also needs a delegated Route 53 zone for `seudd.online` so ACM can validate the certificate.

Before applying, configure:

- AWS credentials for the initial Terraform setup
- The backend bucket and DynamoDB lock table
- The ECR image used by the ECS task
- DevOps Agent webhook settings for the development AIOps path
- Slack workspace and channel identifiers if Chatbot approval is enabled

After the first image is available in ECR, the build workflow can publish later images and force a new ECS deployment.

---

## Cost controls

AWS costs depend on how long the resources run and how much traffic they handle. The main ongoing costs are:

| Resource | Cost control |
|----------|--------------|
| NAT Gateway | Set `deploy_nat_gateway = false` when outbound access is not needed |
| ECS Fargate | Scale the service to zero between sessions |
| RDS PostgreSQL | Stop the development instance when it is not in use |
| ALB and WAF | Destroy the environment when the demonstration is complete |
| CloudWatch, SQS and Lambda | Remove unused environments and review log retention |

The Terraform state, ECR repository and lock table are persistent resources. Keep them separate from the application environment and review their retention before a full teardown.

---

## Teardown

For a short break between development sessions:

```bash
aws ecs update-service \
  --cluster dev-b2b-cluster \
  --service dev-b2b-monolith-service \
  --desired-count 0
```

Then set `deploy_nat_gateway = false` in the development variables and apply Terraform. Stop the development RDS instance from the AWS console.

For a full environment teardown, run `terraform-destroy.yml` from GitHub Actions. The workflow requires `destroy-prod` for production.

Keep the persistent Terraform resources unless you intend to recreate the state, lock table, ECR repository and OIDC roles.

---

## Live verification

Check the service health endpoint through the ALB or production domain:

```bash
curl -s https://seudd.online/health
```

Expected response:

```json
{"status":"healthy"}
```

| Check | Expected result |
|-------|-----------------|
| `/health` | Returns `{"status":"healthy"}` |
| `/store` | Storefront loads |
| `/products` | Seeded product catalogue is returned |
| Login | JWT is returned for the seeded account |
| Order creation | An authenticated request creates an order |
| Payment | The simulator returns success or the deliberate `66.60` failure |
| Notification flow | Successful payments publish to SQS when configured |

There is currently no application test suite. The repository's automated validation focuses on Terraform formatting and validation, TFLint, Checkov, container scanning and deployment workflows.

---

## Design decisions

| Choice | Reason |
|--------|--------|
| Modular monolith | Keeps the five business areas separate without the cost of five deployed services |
| Zero cross-module joins | Prevents domain logic from depending directly on another module's tables |
| Same-origin storefront | Serves the UI and API from one container without CORS configuration |
| SQS plus DLQ | Keeps notification work out of the checkout request and preserves failed messages |
| Container-image Lambda | Reuses the application image and notification code |
| OIDC for GitHub Actions | Removes long-lived AWS credentials from CI/CD |
| ADOT sidecar | Sends application telemetry to AWS without adding tracing code to each route |
| Optional NAT Gateway | Allows the development environment to be made cheaper when idle |
| Approval before remediation | Keeps the operator in control of infrastructure changes |

---

## Author

**Sudd** — Cloud & DevOps Engineer<br/>
GitHub: [@sudd22](https://github.com/sudd22) · Repository: [sudd22/ECS-online-boutique](https://github.com/sudd22/ECS-online-boutique)

This project is inspired by Google's Online Boutique architecture and adapted into a modular monolith on AWS. Payments are simulated for demonstration purposes.
