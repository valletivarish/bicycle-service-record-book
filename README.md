# Bicycle Service Record Book

A small web application for a bicycle repair desk. Staff write a job sheet for each
service (bicycle label, service date, work carried out, recorded cost and status),
look them up in a service index, edit them, print them and delete them.

## Stack

- Frontend: Angular 22 (standalone components, production build served as static files)
- API: Node.js 22 + Express 5, `pg` driver, plain SQL migrations
- Database: PostgreSQL 16 (Amazon RDS on AWS, a container locally and in CI)
- AWS (us-east-1): S3 + CloudFront for the Angular build, CloudFront `/api/*` to Nginx
  on one EC2 t3.micro (Elastic IP) running the API container, private RDS, ECR for
  API images, SSM Parameter Store for the database password, CloudWatch for health
  and CPU
- CI/CD: one GitHub Actions workflow (`.github/workflows/ci-cd.yml`)
- Infrastructure as code: Terraform (`infra/terraform`)

## Structure

```text
code/                 Angular app (src/, angular.json, package.json)
code/server/          Express API (src/, migrations/, test/, package.json)
infra/docker/         API Dockerfile
infra/nginx/          Nginx configs (local stack and EC2 /api/ proxy)
infra/systemd/        Health metric timer for the EC2 host
infra/terraform/      AWS infrastructure
infra/docker-compose.yml  Local stack: PostgreSQL + API + Nginx
scripts/              Deploy, rollback, smoke test, bootstrap and CI helper scripts
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
2. `bash scripts/bootstrap-state.sh` (once per account: state bucket and site bucket).
3. `cd infra/terraform && terraform init -backend-config="bucket=<account-id>-servicebook-tfstate" && terraform apply`
4. Set the GitHub secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
   and the account ID in `EXPECTED_AWS_ACCOUNT_ID` in the workflow.
5. Push to `main`: the CD job pushes the image to ECR, restarts the container on EC2
   through SSM (rolling back to the previous image if the health check fails), syncs
   the Angular build to S3, invalidates `index.html` and runs `scripts/smoke-test.sh`.

Manual recovery on the host: `scripts/rollback.sh` starts the previous good image again.
