# AWS Terraform Samples

A collection of Terraform configurations for deploying AWS infrastructure including VPC networking, ECS Fargate services, Lambda functions, RDS PostgreSQL, API Gateway, and more.

## Architecture Overview

This project provisions the following AWS infrastructure:

- **VPC** with public and private subnets across 3 availability zones
- **ECS Fargate** cluster running an Nginx service behind an Application Load Balancer
- **RDS PostgreSQL** database in private subnets
- **Lambda Functions** for database queries, Bedrock AI integration, and ECS task triggering
- **API Gateway (HTTP)** with Cognito JWT authentication
- **S3** bucket for file ingestion
- **SQS** FIFO queue for message processing
- **ECR** repositories for container images

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- AWS CLI configured with appropriate credentials
- An S3 bucket for Terraform state storage (configured in `state.tf`)
- SSL certificate ARN (for HTTPS endpoints)
- Route53 hosted zone ID (for DNS records)

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `projectname` | Project name used for resource naming | `cfeg` |
| `networkcidr` | First two octets of the VPC CIDR | `192.168` |
| `awsregion` | AWS region for deployment | `us-east-2` |
| `certarn` | ARN of the SSL certificate | `""` |
| `hostedzoneid` | Route53 hosted zone ID | `""` |

### Terraform State

State is stored in an S3 bucket with server-side encryption enabled. Update `state.tf` with your bucket name:

```hcl
terraform {
  backend "s3" {
    bucket       = "your-tf-state-bucket"
    key          = "terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
```

## Infrastructure Components

### Networking (`modules/vpc`)

- VPC with `/16` CIDR block
- 3 public subnets (for ALB, NAT Gateway)
- 3 private subnets (for ECS, RDS, Lambda)
- Internet Gateway for public subnet routing
- NAT Gateway for private subnet internet access
- Separate route tables for public and private subnets

### ECS Fargate (`modules/ecs`)

- ECS cluster with Fargate launch type
- Nginx task definition with CloudWatch logging
- Application Load Balancer with HTTPS listener (HTTP redirects to HTTPS)
- ECS Execute Command enabled for debugging
- Deployment circuit breaker with automatic rollback
- Sample batch task definition for background processing

### Database (`modules/rds`)

- PostgreSQL 17 on `db.t4g.large` instance
- 100GB storage with auto-scaling up to 1TB
- Encryption at rest enabled
- 7-day backup retention
- Credentials stored in SSM Parameter Store (SecureString)
- Private subnet placement (not publicly accessible)

### Lambda Functions (`modules/lambda`)

Three Lambda functions are configured:

1. **Sample** (Node.js 22) - Queries PostgreSQL database via API Gateway
2. **Bedrock Sample** (Python 3.13) - Invokes Claude AI via Amazon Bedrock
3. **ECS Task Sample** (Node.js 22) - Triggers Fargate tasks on demand

All functions run in VPC private subnets with appropriate IAM permissions.

### API Gateway (`modules/api-gateway`)

HTTP API with the following routes:

| Route | Lambda | Auth Required |
|-------|--------|---------------|
| `GET /` | sample | No |
| `GET /message/{id}` | sample | Yes (JWT) |
| `GET /bedrock` | bedrock-sample | Yes (JWT) |
| `GET /runtask` | ecs-task-sample | Yes (JWT) |

Authentication is handled by Amazon Cognito with JWT tokens.

### Container Registries (`modules/ecr`)

- `{projectname}-api` - Main API container images
- `{projectname}-sample-task` - Batch task container images

### Storage and Messaging

- **S3** (`modules/s3`) - `{projectname}-file-ingest` bucket for file uploads
- **SQS** (`modules/sqs`) - FIFO queue with content-based deduplication

### IAM (`modules/iam`)

GitHub Actions deployment user with permissions to update Lambda function code.

### EC2 (`modules/ec2`)

Utility EC2 instance in private subnet with SSM Session Manager access for administrative tasks.

## Usage

### Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply
```

### Authenticating with API Gateway

1. Get the Cognito user password from SSM Parameter Store:
   ```bash
   aws ssm get-parameter --name "{projectname}-cognito-user-pw" --with-decryption --query 'Parameter.Value' --output text
   ```

2. Obtain a JWT token:
   ```bash
   token=$(curl -s --location --request POST 'https://cognito-idp.us-east-2.amazonaws.com' \
     --header 'X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth' \
     --header 'Content-Type: application/x-amz-json-1.1' \
     --data-raw '{
       "AuthParameters": {"USERNAME": "edgarpoc", "PASSWORD": "YOUR_PASSWORD"},
       "AuthFlow": "USER_PASSWORD_AUTH",
       "ClientId": "YOUR_CLIENT_ID"
     }' | jq -r '.AuthenticationResult.IdToken')
   ```

3. Call protected endpoints:
   ```bash
   curl https://api.edgar.oddball.io/bedrock --header "Authorization: Bearer ${token}"
   ```

### Connecting to RDS

The database is not publicly accessible. Connect via:
- ECS Execute Command on a running task
- SSM Session Manager on the utility EC2 instance
- Lambda functions in the same VPC

## File Structure

```
.
├── main.tf           # Root module — wires all child modules together
├── state.tf          # Terraform backend config (S3)
├── variables.tf      # Input variables
├── frontend/         # Test UI for API access
│   ├── index.html    # Dashboard with API response display
│   ├── login.html    # Cognito authentication form
│   └── style.css     # Shared styles
├── lambda/
│   ├── bedrock/      # Bedrock AI Lambda (Python)
│   ├── ecs-task/     # ECS task trigger Lambda (Node.js)
│   └── sample/       # Database query Lambda (Node.js)
└── modules/
    ├── api-gateway/  # HTTP API, routes, Cognito auth
    ├── ec2/          # Utility EC2 instance
    ├── ecr/          # Container registries
    ├── ecs/          # ECS cluster, services, ALB
    ├── iam/          # GitHub Actions deploy user
    ├── lambda/       # Lambda functions and IAM
    ├── rds/          # PostgreSQL database
    ├── s3/           # S3 bucket
    ├── sqs/          # SQS FIFO queue
    └── vpc/          # VPC, subnets, routing
```

## Frontend Test UI

The `frontend/` directory contains a simple browser-based UI for testing Cognito authentication and API Gateway access. Built with [Alpine.js](https://alpinejs.dev/) for minimal dependencies.

### Files

| File | Purpose |
|------|---------|
| `login.html` | Login form that authenticates with Cognito using `USER_PASSWORD_AUTH` flow |
| `index.html` | Dashboard that calls protected API endpoints using the stored JWT |
| `style.css` | Shared stylesheet |

### Usage

1. Open `login.html` in a browser
2. Enter Cognito user credentials
3. On successful login, the JWT is stored in `localStorage` and you're redirected to `index.html`
4. The dashboard automatically calls `GET /message/2` with the JWT in the Authorization header
5. The API response is displayed on the page

**Note:** The frontend currently routes API calls through a public CORS proxy (`test.cors.workers.dev`) to work around CORS configuration issues. This is for testing only and should not be used in production.

## Security Considerations

- All secrets are stored in SSM Parameter Store as SecureString
- Database credentials are randomly generated
- RDS is not publicly accessible
- ECS tasks run in private subnets
- API Gateway protected routes require JWT authentication
- HTTPS enforced with HTTP-to-HTTPS redirect
