# AWS Infrastructure Architecture - Complete Guide

## ASCII Architecture Diagram

```
                                    INTERNET
                                       |
                                       |
                    +------------------+------------------+
                    |                                     |
                    |      Application Load Balancer      |
                    |         (Public Facing)             |
                    +------------------+------------------+
                                       |
                    +------------------+------------------+
                    |                                     |
        +-----------v-----------+           +-----------v-----------+
        |   PUBLIC SUBNET 1     |           |   PUBLIC SUBNET 2     |
        |   (ap-south-1a)       |           |   (ap-south-1b)       |
        |   10.0.1.0/24         |           |   10.0.2.0/24         |
        |                       |           |                       |
        |  +----------------+   |           |  +----------------+   |
        |  | Frontend EC2   |   |           |  | Frontend EC2   |   |
        |  | Auto Scaling   |   |           |  | Auto Scaling   |   |
        |  | (2-4 instances)|   |           |  | (2-4 instances)|   |
        |  +----------------+   |           |  +----------------+   |
        +-----------+-----------+           +-----------+-----------+
                    |                                   |
                    |         NAT GATEWAY               |
                    +------------------+----------------+
                                       |
        +------------------------------+------------------------------+
        |                                                             |
        +-----------v-----------+           +-----------v-----------+
        |  PRIVATE SUBNET 1     |           |  PRIVATE SUBNET 2     |
        |   (ap-south-1a)       |           |   (ap-south-1b)       |
        |   10.0.10.0/24        |           |   10.0.11.0/24        |
        |                       |           |                       |
        |  +----------------+   |           |  +----------------+   |
        |  | Backend EC2    |   |           |  | Backend EC2    |   |
        |  | Auto Scaling   |   |           |  | Auto Scaling   |   |
        |  | (2-4 instances)|   |           |  | (2-4 instances)|   |
        |  +----------------+   |           |  +----------------+   |
        |         |             |           |         |             |
        +---------+-------------+           +---------+-------------+
                  |                                   |
                  |         VPC Endpoint              |
                  +------------------+----------------+
                                     |
                          +----------v----------+
                          |                     |
                          |   DynamoDB Table    |
                          |   (app-data-table)  |
                          |                     |
                          +---------------------+
```

## Network Flow Diagram

```
User Request Flow:
==================

1. User (Internet) 
   ↓
2. Application Load Balancer (Port 80/443)
   ↓
3. Frontend EC2 Instances (Public Subnet)
   ↓
4. Backend EC2 Instances (Private Subnet, Port 3000)
   ↓
5. DynamoDB (via VPC Endpoint)
   ↓
6. Response back through same path
```



## Detailed Component Explanation

### 1. VPC (Virtual Private Cloud)
**Code Location:** `main.tf` lines 14-22

```terraform
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

**What it does:**
- Creates an isolated virtual network in AWS
- CIDR block `10.0.0.0/16` provides 65,536 IP addresses
- DNS support allows instances to resolve domain names
- DNS hostnames enable instances to get public DNS names

**Why we need it:**
- Provides network isolation and security
- Allows you to control IP addressing
- Required for all EC2 instances and networking resources

---

### 2. Internet Gateway
**Code Location:** `main.tf` lines 24-31

```terraform
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
```

**What it does:**
- Connects your VPC to the internet
- Allows resources in public subnets to communicate with the internet
- Enables inbound traffic from the internet to reach your ALB

**Why we need it:**
- Without it, your application can't be accessed from the internet
- Required for public-facing resources like ALB and frontend servers

---

### 3. Public Subnets (2 Availability Zones)
**Code Location:** `main.tf` lines 33-57

```terraform
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}
```

**What it does:**
- Creates two subnets in different availability zones (AZs)
- `10.0.1.0/24` = 256 IP addresses per subnet
- `map_public_ip_on_launch = true` automatically assigns public IPs to instances

**Why we need it:**
- High availability: If one AZ fails, the other continues working
- ALB requires at least 2 subnets in different AZs
- Frontend servers need public IPs to receive traffic from ALB

---

### 4. Private Subnets (2 Availability Zones)
**Code Location:** `main.tf` lines 59-83

```terraform
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-south-1a"
}
```

**What it does:**
- Creates two private subnets (no direct internet access)
- Backend servers are placed here for security
- Can only access internet through NAT Gateway

**Why we need it:**
- Security: Backend servers are not directly exposed to internet
- Best practice: Keep application logic and databases in private subnets
- Reduces attack surface

---

### 5. NAT Gateway
**Code Location:** `main.tf` lines 85-104

```terraform
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id
}
```

**What it does:**
- Allows private subnet instances to access the internet
- Uses an Elastic IP (static public IP)
- Placed in public subnet but serves private subnet

**Why we need it:**
- Backend servers need to download updates, packages, etc.
- Enables outbound internet access without exposing servers
- One-way traffic: Servers can initiate connections out, but internet can't initiate connections in

---

### 6. Route Tables
**Code Location:** `main.tf` lines 106-145

```terraform
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}
```

**What it does:**
- Public route table: Directs all internet traffic (0.0.0.0/0) to Internet Gateway
- Private route table: Directs all internet traffic to NAT Gateway
- Associates subnets with appropriate route tables

**Why we need it:**
- Controls how traffic flows in and out of subnets
- Public subnets get direct internet access
- Private subnets get internet access through NAT



---

### 7. Security Groups

#### A. ALB Security Group
**Code Location:** `main.tf` lines 147-177

```terraform
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**What it does:**
- Acts as a virtual firewall for the ALB
- Allows HTTP (port 80) and HTTPS (port 443) from anywhere
- Allows all outbound traffic

**Why we need it:**
- Users need to access your application from the internet
- Security: Only allows web traffic, blocks everything else

---

#### B. Frontend Security Group
**Code Location:** `main.tf` lines 179-213

```terraform
resource "aws_security_group" "frontend" {
  name        = "frontend-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**What it does:**
- Allows HTTP traffic ONLY from ALB (not directly from internet)
- Allows SSH (port 22) for server management
- Allows all outbound traffic

**Why we need it:**
- Security: Frontend only accepts traffic from ALB
- SSH access for troubleshooting and maintenance
- Prevents direct access bypassing the load balancer

---

#### C. Backend Security Group
**Code Location:** `main.tf` lines 215-249

```terraform
resource "aws_security_group" "backend" {
  name        = "backend-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**What it does:**
- Allows application traffic (port 3000) ONLY from frontend servers
- Allows SSH only from public subnets (for bastion/jump host access)
- Allows all outbound traffic

**Why we need it:**
- Maximum security: Backend is completely isolated from internet
- Only frontend can communicate with backend
- SSH access through public subnet (bastion host pattern)

---

### 8. VPC Endpoint for DynamoDB
**Code Location:** `main.tf` lines 251-259

```terraform
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.ap-south-1.dynamodb"
  route_table_ids = [aws_route_table.private.id]
}
```

**What it does:**
- Creates a private connection to DynamoDB
- Traffic stays within AWS network (doesn't go through internet)
- Associated with private route table

**Why we need it:**
- Better security: Database traffic never leaves AWS network
- Lower latency: Direct connection to DynamoDB
- No data transfer costs for DynamoDB access
- No need for NAT Gateway for DynamoDB traffic

---

### 9. DynamoDB Table
**Code Location:** `main.tf` lines 261-274

```terraform
resource "aws_dynamodb_table" "main" {
  name           = "app-data-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
```

**What it does:**
- Creates a NoSQL database table
- `PAY_PER_REQUEST` = You only pay for what you use (no provisioned capacity)
- `hash_key = "id"` = Primary key is "id" field
- `type = "S"` = String type

**Why we need it:**
- Stores application data
- Serverless: No servers to manage
- Auto-scales based on demand
- Highly available and durable

