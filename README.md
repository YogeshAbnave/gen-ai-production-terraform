# CRUD Application - React + FastAPI + DynamoDB

A production-ready full-stack CRUD application with automated AWS deployment using Terraform and GitHub Actions.

**Repository:** https://github.com/YogeshAbnave/terraform-crud

---

## 📑 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Local Development](#local-development)
- [AWS Deployment](#aws-deployment)
- [Configuration](#configuration)
- [API Reference](#api-reference)
- [Scripts Reference](#scripts-reference)
- [Troubleshooting](#troubleshooting)
- [Tech Stack](#tech-stack)

---

## 🎯 Overview

This is a complete full-stack application featuring:

- **Frontend:** React 18 with Vite for fast development
- **Backend:** FastAPI (Python) with async support
- **Database:** AWS DynamoDB (serverless NoSQL)
- **Infrastructure:** Terraform for Infrastructure as Code
- **Deployment:** Automated CI/CD with GitHub Actions
- **Scaling:** Auto Scaling Groups with Application Load Balancer

### Key Features

✅ Full CRUD operations (Create, Read, Update, Delete)  
✅ Responsive UI with modern design  
✅ RESTful API with FastAPI  
✅ Serverless database with DynamoDB  
✅ Auto-scaling infrastructure  
✅ Automated deployment pipeline  
✅ Infrastructure as Code with Terraform  
✅ Health checks and monitoring  

---

## 🏗 Architecture

```
Internet → ALB → EC2 Instances (Auto Scaling) → DynamoDB
           ↓
    Frontend (React + NGINX)
    Backend (FastAPI + Uvicorn)
```

### AWS Infrastructure

- **VPC:** Custom VPC with public and private subnets across 2 AZs
- **ALB:** Application Load Balancer for traffic distribution
- **ASG:** Auto Scaling Group (2-4 instances) for high availability
- **EC2:** Ubuntu instances running NGINX + FastAPI
- **DynamoDB:** Serverless NoSQL database
- **IAM:** Roles and policies for secure access
- **Security Groups:** Network-level security

For detailed architecture diagrams, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## 📋 Prerequisites

### Required Software

- **Python 3.11+** - [Download](https://www.python.org/downloads/)
- **Node.js 20+** - [Download](https://nodejs.org/)
- **Terraform** - [Download](https://www.terraform.io/downloads)
- **AWS CLI** - [Download](https://aws.amazon.com/cli/)
- **Git** - [Download](https://git-scm.com/)

### AWS Account Setup

1. Create an AWS account
2. Configure AWS CLI:
   ```powershell
   aws configure
   ```
3. Enter your AWS credentials:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region: `ap-south-1`
   - Default output format: `json`

### Verify Installation

```powershell
python --version    # Should be 3.11+
node --version      # Should be 20+
terraform --version
aws --version
aws sts get-caller-identity  # Verify AWS credentials
```

---

## 🚀 Quick Start

### Option 1: Local Development

```powershell
# 1. Setup (first time only)
.\scripts\run-local.ps1 -Setup

# 2. Run backend (Terminal 1)
.\scripts\run-local.ps1 -Backend

# 3. Run frontend (Terminal 2)
.\scripts\run-local.ps1 -Frontend

# 4. Access application
# http://localhost:3000
```

### Option 2: AWS Deployment

```powershell
# 1. Deploy infrastructure
.\scripts\deploy.ps1 -Deploy

# 2. Get GitHub secrets
.\scripts\deploy.ps1 -Secrets

# 3. Add secrets to GitHub
# Go to: https://github.com/YOUR_USERNAME/terraform-crud/settings/secrets/actions
# Add: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, EC2_PRIVATE_KEY

# 4. Push code to trigger deployment
.\scripts\deploy.ps1 -Push
```

---

## 📁 Project Structure

```
terraform-crud/
├── README.md                      # This file
├── .gitignore                     # Git ignore rules
│
├── src/                           # Application source code
│   ├── frontend/                  # React application
│   │   ├── src/
│   │   │   ├── pages/            # UI pages (List, Create, Edit)
│   │   │   ├── services/         # API client
│   │   │   ├── App.jsx           # Main app component
│   │   │   └── main.jsx          # Entry point
│   │   ├── index.html
│   │   ├── package.json
│   │   └── vite.config.js
│   │
│   └── backend/                   # FastAPI application
│       ├── app/
│       │   ├── main.py           # FastAPI app + routes
│       │   ├── crud.py           # DynamoDB operations
│       │   └── models.py         # Pydantic models
│       └── requirements.txt
│
├── infrastructure/                # Terraform IaC
│   ├── main.tf                   # Provider configuration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── vpc.tf                    # VPC, subnets, routing
│   ├── alb.tf                    # Application Load Balancer
│   ├── asg.tf                    # Auto Scaling Group
│   ├── security-groups.tf        # Security groups
│   ├── iam.tf                    # IAM roles and policies
│   ├── dynamodb.tf               # DynamoDB table
│   └── scripts/
│       └── user_data.sh          # EC2 initialization script
│
├── scripts/                       # Utility scripts
│   ├── run-local.ps1             # Local development
│   ├── deploy.ps1                # Deployment automation
│   ├── get-secrets.ps1           # Extract GitHub secrets (Windows)
│   ├── get-secrets.sh            # Extract GitHub secrets (Unix)
│   └── check-infrastructure.ps1  # Verify AWS infrastructure
│
├── docs/                          # Documentation
│   └── ARCHITECTURE.md           # Detailed architecture diagrams
│
├── .github/                       # CI/CD
│   └── workflows/
│       └── deploy.yml            # GitHub Actions workflow
│
└── load-testing/                  # Performance testing (optional)
    ├── locustfile.py
    └── README.md
```

---

## 💻 Local Development

### First Time Setup

```powershell
# Install all dependencies
.\scripts\run-local.ps1 -Setup
```

This will:
- Create Python virtual environment
- Install Python dependencies
- Install Node.js dependencies

### Running the Application

**Backend (Terminal 1):**
```powershell
.\scripts\run-local.ps1 -Backend
```
- Starts FastAPI server on `http://localhost:8000`
- API docs available at `http://localhost:8000/docs`

**Frontend (Terminal 2):**
```powershell
.\scripts\run-local.ps1 -Frontend
```
- Starts Vite dev server on `http://localhost:3000`
- Hot reload enabled

### Development Workflow

1. Make code changes
2. Frontend auto-reloads
3. Backend auto-reloads (with `--reload` flag)
4. Test locally before deploying

### Environment Variables

Backend uses these environment variables:
- `DYNAMODB_TABLE`: DynamoDB table name (default: `app-data-table`)
- `AWS_REGION`: AWS region (default: `ap-south-1`)
- `AWS_ACCESS_KEY_ID`: AWS credentials
- `AWS_SECRET_ACCESS_KEY`: AWS credentials

---

## ☁️ AWS Deployment

### Deployment Order (IMPORTANT!)

⚠️ **You MUST deploy infrastructure BEFORE pushing code to GitHub!**

```
1. Deploy Terraform → 2. Configure GitHub Secrets → 3. Push Code
```

### Step-by-Step Deployment

#### Step 1: Deploy Infrastructure

```powershell
.\scripts\deploy.ps1 -Deploy
```

This will:
- Initialize Terraform
- Create VPC, subnets, and networking
- Create Application Load Balancer
- Create Auto Scaling Group
- Launch EC2 instances
- Create DynamoDB table
- Generate SSH keys
- Configure security groups

**Time:** ~5-7 minutes

#### Step 2: Get GitHub Secrets

```powershell
.\scripts\deploy.ps1 -Secrets
```

This will display:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `EC2_PRIVATE_KEY`

#### Step 3: Add Secrets to GitHub

1. Go to: `https://github.com/YOUR_USERNAME/terraform-crud/settings/secrets/actions`
2. Click "New repository secret"
3. Add each secret:
   - Name: `AWS_ACCESS_KEY_ID`, Value: (from AWS)
   - Name: `AWS_SECRET_ACCESS_KEY`, Value: (from AWS)
   - Name: `EC2_PRIVATE_KEY`, Value: (entire private key including BEGIN/END lines)

#### Step 4: Push Code

```powershell
.\scripts\deploy.ps1 -Push
```

Or manually:
```powershell
git add .
git commit -m "Deploy application"
git push origin main
```

This triggers GitHub Actions which will:
- Build frontend
- Install backend dependencies
- Deploy to all EC2 instances
- Restart services
- Verify health

**Time:** ~3-5 minutes

### Verify Deployment

1. Check GitHub Actions: `https://github.com/YOUR_USERNAME/terraform-crud/actions`
2. Get ALB DNS:
   ```powershell
   cd infrastructure
   terraform output alb_dns_name
   ```
3. Access application: `http://<ALB_DNS>`

### Automated Deployment Script

Run all steps with prompts:
```powershell
.\scripts\deploy.ps1 -All
```

---

## ⚙️ Configuration

### AWS Region

This project is configured for **`ap-south-1`** (Mumbai, India).

To change region:

1. Update `infrastructure/variables.tf`:
   ```hcl
   variable "aws_region" {
     default = "your-region"
   }
   ```

2. Update `.github/workflows/deploy.yml`:
   ```yaml
   env:
     AWS_REGION: your-region
   ```

3. Ensure both match to avoid deployment errors

### DynamoDB Table

Table name: `app-data-table`  
Primary key: `id` (String)  
Billing mode: Pay-per-request (serverless)

### Auto Scaling

- **Min instances:** 2
- **Max instances:** 4
- **Desired capacity:** 2
- **Scale up:** CPU > 70% for 2 minutes
- **Scale down:** CPU < 30% for 5 minutes

### Security Groups

- **ALB:** Allows HTTP (80) and HTTPS (443) from internet
- **Frontend:** Allows HTTP (80) from ALB only
- **Backend:** Allows port 3000 from frontend only

---

## 📡 API Reference

Base URL: `http://<ALB_DNS>/api`

### Endpoints

| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| GET | `/api/` | API root | - |
| GET | `/api/health` | Health check | - |
| POST | `/api/items` | Create item | `{"name": "string", "description": "string"}` |
| GET | `/api/items` | List all items | - |
| GET | `/api/items/{id}` | Get item by ID | - |
| PUT | `/api/items/{id}` | Update item | `{"name": "string", "description": "string"}` |
| DELETE | `/api/items/{id}` | Delete item | - |

### Example Requests

**Create Item:**
```bash
curl -X POST http://<ALB_DNS>/api/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "This is a test"}'
```

**Get All Items:**
```bash
curl http://<ALB_DNS>/api/items
```

**Update Item:**
```bash
curl -X PUT http://<ALB_DNS>/api/items/{id} \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Item", "description": "Updated description"}'
```

**Delete Item:**
```bash
curl -X DELETE http://<ALB_DNS>/api/items/{id}
```

### API Documentation

Interactive API docs available at:
- Swagger UI: `http://<ALB_DNS>/api/docs`
- ReDoc: `http://<ALB_DNS>/api/redoc`

---

## 📜 Scripts Reference

### run-local.ps1

Local development script.

```powershell
# Setup (first time)
.\scripts\run-local.ps1 -Setup

# Run backend
.\scripts\run-local.ps1 -Backend

# Run frontend
.\scripts\run-local.ps1 -Frontend

# Show instructions
.\scripts\run-local.ps1 -Both
```

### deploy.ps1

AWS deployment automation.

```powershell
# Deploy infrastructure
.\scripts\deploy.ps1 -Deploy

# Show GitHub secrets
.\scripts\deploy.ps1 -Secrets

# Push code to GitHub
.\scripts\deploy.ps1 -Push

# Run all steps
.\scripts\deploy.ps1 -All

# Destroy infrastructure
.\scripts\deploy.ps1 -Destroy
```

### check-infrastructure.ps1

Verify AWS infrastructure before deployment.

```powershell
.\scripts\check-infrastructure.ps1
```

Checks:
- AWS credentials
- VPC
- Application Load Balancer
- Auto Scaling Group
- EC2 instances
- DynamoDB table

### get-secrets.ps1 / get-secrets.sh

Extract GitHub secrets from Terraform.

```powershell
# Windows
.\scripts\get-secrets.ps1

# Linux/Mac
./scripts/get-secrets.sh
```

---

## 🔍 Troubleshooting

### Common Issues

#### 1. LoadBalancerNotFound Error

**Error:** `LoadBalancerNotFound when calling DescribeLoadBalancers`

**Cause:** Terraform infrastructure not deployed

**Solution:**
```powershell
cd infrastructure
terraform init
terraform apply
```

#### 2. No Running Instances Found

**Error:** `No running instances found in ASG`

**Cause:** Auto Scaling Group not created or instances still launching

**Solution:**
```powershell
# Wait 2-3 minutes for instances to launch
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=crud-app-asg" \
  --region ap-south-1
```

#### 3. Permission Denied (publickey)

**Error:** `Permission denied (publickey)`

**Cause:** EC2_PRIVATE_KEY GitHub secret missing or incorrect

**Solution:**
1. Get private key:
   ```powershell
   .\scripts\get-secrets.ps1
   ```
2. Copy **entire** key (including BEGIN/END lines)
3. Add to GitHub secrets as `EC2_PRIVATE_KEY`

#### 4. Health Check Failed (502 Bad Gateway)

**Error:** `502 Bad Gateway`

**Cause:** Backend services not running or not healthy

**Solutions:**

**A. Wait for services to start** (1-2 minutes after deployment)

**B. Check service status:**
```powershell
# SSH into instance
ssh -i .ssh/crud-app-key ubuntu@<INSTANCE_IP>

# Check FastAPI
sudo systemctl status fastapi

# Check NGINX
sudo systemctl status nginx

# View logs
sudo journalctl -u fastapi -n 50
```

**C. Restart services:**
```bash
sudo systemctl restart fastapi
sudo systemctl restart nginx
```

#### 5. AWS Credentials Not Configured

**Error:** `Unable to locate credentials`

**Solution:**
```powershell
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `ap-south-1`
- Default output format: `json`

### Backend Issues

**Virtual environment not found:**
```powershell
.\scripts\run-local.ps1 -Setup
```

**DynamoDB table not found:**
```powershell
cd infrastructure
terraform apply
```

**Module not found:**
```powershell
cd src/backend
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Frontend Issues

**Build fails:**
```powershell
cd src/frontend
Remove-Item -Recurse node_modules
npm install
npm run build
```

**Can't connect to backend:**
- Ensure backend is running on port 8000
- Check browser console for errors
- Verify `vite.config.js` proxy settings

### Deployment Issues

**GitHub Actions failing:**
1. Check logs: `https://github.com/YOUR_USERNAME/terraform-crud/actions`
2. Verify all secrets are added
3. Ensure infrastructure is deployed
4. Check EC2 instances are running

**Terraform errors:**
```powershell
cd infrastructure
terraform init
terraform validate
terraform plan
```

### Verification Commands

**Check infrastructure:**
```powershell
.\scripts\check-infrastructure.ps1
```

**Check ALB:**
```powershell
aws elbv2 describe-load-balancers --names crud-app-alb --region ap-south-1
```

**Check ASG:**
```powershell
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names crud-app-asg --region ap-south-1
```

**Check DynamoDB:**
```powershell
aws dynamodb describe-table --table-name app-data-table --region ap-south-1
```

**SSH into EC2:**
```powershell
ssh -i .ssh/crud-app-key ubuntu@<EC2_IP>
```

---

## 📚 Tech Stack

### Frontend
- **React 18** - UI library
- **Vite** - Build tool and dev server
- **Axios** - HTTP client
- **React Router** - Client-side routing
- **CSS3** - Styling

### Backend
- **FastAPI** - Modern Python web framework
- **Uvicorn** - ASGI server
- **Boto3** - AWS SDK for Python
- **Pydantic** - Data validation

### Database
- **AWS DynamoDB** - Serverless NoSQL database

### Infrastructure
- **Terraform** - Infrastructure as Code
- **AWS VPC** - Virtual Private Cloud
- **AWS ALB** - Application Load Balancer
- **AWS ASG** - Auto Scaling Group
- **AWS EC2** - Virtual servers (Ubuntu)
- **NGINX** - Web server and reverse proxy

### CI/CD
- **GitHub Actions** - Automated deployment pipeline

### Development Tools
- **Git** - Version control
- **AWS CLI** - AWS command-line interface
- **PowerShell** - Automation scripts

---

## 🧹 Cleanup

To destroy all AWS resources:

```powershell
.\scripts\deploy.ps1 -Destroy
```

Or manually:
```powershell
cd infrastructure
terraform destroy -auto-approve
```

**Warning:** This will permanently delete:
- All EC2 instances
- Load Balancer
- Auto Scaling Group
- VPC and networking
- DynamoDB table (and all data)

---

## 📄 License

MIT License

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit a pull request

---

## 📞 Support

- **Issues:** https://github.com/YogeshAbnave/terraform-crud/issues
- **Discussions:** https://github.com/YogeshAbnave/terraform-crud/discussions
- **Documentation:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## 🎉 Success!

Your application is now running on AWS with:
- ✅ Auto-scaling infrastructure
- ✅ Load balancing
- ✅ High availability (multi-AZ)
- ✅ Automated deployments
- ✅ Infrastructure as Code

**Application URL:** `http://<ALB_DNS>`  
**API Documentation:** `http://<ALB_DNS>/api/docs`  
**GitHub Actions:** `https://github.com/YOUR_USERNAME/terraform-crud/actions`

---

**Built with ❤️ using React, FastAPI, and AWS**
