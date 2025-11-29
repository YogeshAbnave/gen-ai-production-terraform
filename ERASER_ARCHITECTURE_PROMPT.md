# Eraser.io Architecture Diagram Prompt

## Copy and paste this prompt into Eraser.io to generate your architecture diagram:

---

Create a detailed AWS cloud architecture diagram for an AI-powered education platform with the following components and specifications:

## Network Layer (VPC)
- VPC with CIDR 10.0.0.0/16 labeled "Custom VPC"
- Internet Gateway connected to VPC
- NAT Gateway in public subnet

## Availability Zones (2 AZs)
Create two availability zones side by side:

### Availability Zone 1 (us-east-1a):
- Public Subnet (10.0.1.0/24) containing:
  - EC2 instances (2-4 instances) labeled "Streamlit App Servers"
  - Show Auto Scaling Group icon
- Private Subnet (10.0.10.0/24) - empty but labeled

### Availability Zone 2 (us-east-1b):
- Public Subnet (10.0.2.0/24) containing:
  - EC2 instances (2-4 instances) labeled "Streamlit App Servers"
  - Show Auto Scaling Group icon
- Private Subnet (10.0.11.0/24) - empty but labeled

## Load Balancing
- Application Load Balancer (ALB) at the top, receiving traffic from Internet
- ALB distributes traffic to EC2 instances in both AZs
- Show health check connections

## Data & Storage Layer
Below the AZs, show these services:
- DynamoDB table labeled "app-data-table (Assignments & Answers)"
- S3 bucket labeled "education-portal-images"
- VPC Endpoint connecting private subnets to DynamoDB

## AI Services
- AWS Bedrock service box containing:
  - Amazon Titan Text (Question Generation)
  - Amazon Titan Image Generator (Image Creation)
  - Amazon Titan Embeddings (Semantic Grading)
  - Mistral 7B (Grammar Suggestions)

## CDN Layer
- CloudFront distribution at the top
- CloudFront connected to S3 bucket
- Show Origin Access Identity (OAI) connection

## Security Components
- Security Group for ALB (ports 80, 443 from internet)
- Security Group for EC2 (port 80 from ALB only)
- IAM Role attached to EC2 instances with policies for:
  - DynamoDB access
  - S3 access
  - Bedrock access

## Traffic Flow (show with arrows)
1. User → CloudFront → S3 (for images)
2. User → Internet Gateway → ALB → EC2 instances
3. EC2 → DynamoDB (via VPC Endpoint)
4. EC2 → S3 (for image upload)
5. EC2 → Bedrock (for AI operations)
6. EC2 → NAT Gateway → Internet (for outbound)

## Labels and Annotations
- Add "Multi-AZ High Availability" label
- Add "Auto Scaling (2-4 instances)" label
- Add "Pay-per-request billing" on DynamoDB
- Add "24-hour cache TTL" on CloudFront
- Add "AES-256 encryption" on S3
- Show "Public Subnet" and "Private Subnet" labels clearly

## Color Scheme
- Use AWS standard colors
- Public subnets: light blue
- Private subnets: light gray
- Security groups: orange/red borders
- Data flow arrows: blue
- AI services: purple/violet

## Style
- Use AWS architecture icons
- Show clear boundaries for VPC, subnets, and AZs
- Make it professional and presentation-ready
- Include a legend for icons
- Add title: "AI-Powered Education Platform - AWS Architecture"

---

## Alternative Simplified Prompt (if the above is too complex):

Create an AWS architecture diagram showing:
- Internet users connecting through CloudFront CDN and Application Load Balancer
- ALB distributing traffic across EC2 instances in 2 availability zones (us-east-1a and us-east-1b)
- Auto Scaling Group managing 2-4 EC2 instances running Streamlit application
- EC2 instances connecting to DynamoDB for data storage
- EC2 instances connecting to S3 for image storage
- EC2 instances connecting to AWS Bedrock for AI operations (Titan Text, Titan Image, Titan Embeddings, Mistral 7B)
- CloudFront serving images from S3 bucket
- VPC with public subnets (10.0.1.0/24, 10.0.2.0/24) and private subnets (10.0.10.0/24, 10.0.11.0/24)
- Security groups controlling traffic flow
- IAM roles for EC2 to access AWS services
- Show all connections with labeled arrows

Use AWS standard icons and colors. Make it professional and clear.
