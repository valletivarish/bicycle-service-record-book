# Bicycle Service Record Book

A small web application for a bicycle repair desk. Staff write a job sheet for each
service (bicycle label, service date, work carried out, recorded cost and status),
look them up in a service index, edit them, print them and delete them.

## Stack

- Frontend: Angular 22 (standalone components), production build served by Nginx in a container
- API: Node.js 22 + Express 5, `pg` driver, plain SQL migrations
- Database: PostgreSQL 16 (Amazon RDS on AWS, a container locally and in CI)
- AWS (us-east-1): one EC2 t3.micro with an Elastic IP running two containers with
  Docker Compose (web: Nginx + Angular build on port 80, proxying `/api/` to the API
  container), private RDS, ECR for both images, SSM Parameter Store for the database
  password, SSM Run Command for releases, CloudWatch for health and CPU
- CI/CD: one GitHub Actions workflow (`.github/workflows/ci-cd.yml`)
- Infrastructure as code: Terraform (`infra/terraform`)

## Structure

```text
code/                     Angular app (src/, angular.json, package.json)
code/server/              Express API (src/, migrations/, test/, package.json)
infra/docker/             API and web Dockerfiles
infra/nginx/              Nginx config of the web container
infra/systemd/            Health metric timer for the EC2 host
infra/terraform/          AWS infrastructure
infra/compose.aws.yml     Production containers on EC2
infra/docker-compose.yml  Local stack: PostgreSQL + API image + web image
scripts/                  Deploy, rollback, smoke test, bootstrap and CI helper scripts
```

## API

| Method | Path | Notes |
|---|---|---|
| GET | `/api/health` | Runs a database query, returns `{ status, release }` |
| GET | `/api/records?status=&q=` | Newest service first, optional status filter and label search |
| GET | `/api/records/:id` | 404 if missing |
| POST | `/api/records` | 201, or 422 with `{ errors: { field: message } }` |
| PUT | `/api/records/:id` | 200, 404 or 422 |
| DELETE | `/api/records/:id` | 204 or 404 |

Validation: bicycle label and work description are required, the service date must be a
real date and not after today (Europe/Dublin), cost is a non-negative amount with at
most two decimals, status is one of Booked in, In progress, Waiting for parts, Ready for
collection, Collected.

## Run locally

```bash
cd code && npm ci && npm run build && cd ..
docker compose -f infra/docker-compose.yml up --build
# open http://localhost:8090
```

For development, run PostgreSQL, then `cd code/server && npm ci && DATABASE_URL=... npm start`
and `cd code && npm start` (the Angular dev server proxies `/api` to port 3000).

## Test and lint

```bash
cd code/server
DATABASE_URL=postgres://servicebook:servicebook@localhost:5432/servicebook_test npm test
npm run lint
cd .. && npm run lint
```

## Deploy

1. Start the AWS Academy Learner Lab and put its credentials in `~/.aws/credentials`.
2. `bash scripts/bootstrap-state.sh` (once per account: Terraform state bucket).
3. `cd infra/terraform && terraform init -backend-config="bucket=<account-id>-servicebook-tfstate" && terraform apply`
4. Set the GitHub secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
   (they change at every lab start) and the account ID in `EXPECTED_AWS_ACCOUNT_ID`.
5. Push to `main`: the CD job pushes the scanned images to ECR and runs
   `scripts/deploy-release.sh` on the host through SSM Run Command. It starts the
   containers with Docker Compose, checks `/api/health` and the page, and starts the
   previous release again if the check fails. `scripts/smoke-test.sh` then checks the
   public URL. The app is plain HTTP on the Elastic IP (no domain or certificate).

Manual recovery on the host: `bash /opt/service-book/rollback.sh` starts the previous
release again (running it twice goes forward again).
