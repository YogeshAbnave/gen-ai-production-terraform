# Interview Questions - Part 1: Architecture & AWS

## AWS Infrastructure Questions (1-15)

### 1. Can you explain the overall architecture of your application?
**Answer:** The application uses a multi-tier architecture on AWS. Users access the application through an Application Load Balancer, which distributes traffic across EC2 instances in an Auto Scaling Group spanning two availability zones. The application layer runs Streamlit with Python, communicating with DynamoDB for data storage, S3 for image storage, and AWS Bedrock for AI capabilities. CloudFront CDN serves images globally with low latency.

### 2. Why did you choose a multi-AZ deployment?
**Answer:** Multi-AZ deployment provides high availability and fault tolerance. If one availability zone experiences an outage, the application continues running in the other zone. The ALB automatically routes traffic only to healthy instances, ensuring 99.9% uptime. This is critical for an education platform where downtime affects learning.

### 3. Explain your VPC design and subnet strategy.
**Answer:** I created a custom VPC with CIDR 10.0.0.0/16. It has four subnets: two public subnets (10.0.1.0/24 and 10.0.2.0/24) in different AZs for the ALB and frontend, and two private subnets (10.0.10.0/24 and 10.0.11.0/24) for backend services. Public subnets route through an Internet Gateway, while private subnets use a NAT Gateway for outbound internet access, enhancing security.

### 4. How does your Auto Scaling Group work?
**Answer:** The ASG maintains 2-4 EC2 instances based on CPU utilization. It scales up when CPU exceeds 70% for 2 minutes and scales down when CPU drops below 30% for 5 minutes. This ensures cost optimization during low traffic while maintaining performance during peak usage. The ASG automatically replaces unhealthy instances detected by ALB health checks.

### 5. What security measures did you implement?
**Answer:** Multiple layers: Security groups restrict traffic (ALB accepts only HTTP/HTTPS from internet, EC2 accepts traffic only from ALB), IAM roles with least-privilege permissions for EC2 to access DynamoDB/S3/Bedrock, S3 bucket with encryption at rest (AES-256) and blocked public access, VPC endpoints for DynamoDB to keep traffic within AWS network, and private subnets for backend isolation.

### 6. Why did you choose DynamoDB over RDS?
**Answer:** DynamoDB offers serverless scalability with pay-per-request billing, eliminating capacity planning. It provides single-digit millisecond latency, automatic scaling, and built-in high availability across multiple AZs. For this application's access patterns (simple key-value lookups for assignments and answers), DynamoDB is more cost-effective and requires zero database administration.

### 7. Explain your S3 lifecycle management strategy.
**Answer:** I implemented a three-tier lifecycle policy: images remain in Standard storage initially for frequent access, transition to Infrequent Access after 90 days (30% cost savings), move to Glacier after 270 days (80% cost savings), and expire after 635 days total. Images tagged as "Permanent" only transition to IA but never delete, preserving important educational content.

### 8. How does CloudFront improve your application?
**Answer:** CloudFront caches images at edge locations globally, reducing latency from ~500ms to ~50ms for international users. It reduces load on S3 by serving cached content (target 70%+ cache hit ratio), provides HTTPS by default, and reduces data transfer costs. The 24-hour default TTL balances freshness with cache efficiency.

### 9. What is the purpose of the NAT Gateway?
**Answer:** The NAT Gateway allows EC2 instances in private subnets to access the internet for outbound connections (downloading updates, accessing Bedrock APIs) while preventing inbound connections from the internet. This enhances security by keeping backend servers isolated while maintaining necessary internet connectivity.

### 10. How did you implement IAM security?
**Answer:** I created a dedicated IAM role for EC2 instances with three separate policies: DynamoDB policy for CRUD operations on the specific table, S3 policy scoped to the images bucket only, and Bedrock policy for model invocation. This follows the principle of least privilege, granting only necessary permissions and preventing lateral movement in case of compromise.

### 11. What monitoring and alerting did you set up?
**Answer:** I configured CloudWatch dashboards for S3 metrics (bucket size, request count, error rates) and CloudFront metrics (cache hit ratio, request count). I created alarms for S3 upload failure rate >5%, CloudFront cache hit ratio <70%, and S3 bucket size >80% quota. These proactively alert on performance degradation or capacity issues.

### 12. How do you handle EC2 instance failures?
**Answer:** The ALB performs health checks every 30 seconds on each instance. If an instance fails two consecutive checks, the ALB marks it unhealthy and stops routing traffic to it. The Auto Scaling Group detects the unhealthy instance and automatically launches a replacement, ensuring the desired capacity is maintained without manual intervention.

### 13. Explain your deployment strategy.
**Answer:** I use a two-phase deployment: First, Terraform provisions infrastructure (VPC, ALB, ASG, DynamoDB, S3, CloudFront). Second, GitHub Actions deploys application code to all EC2 instances via SSH, installs dependencies, and restarts services. The ALB health checks ensure instances are ready before receiving traffic. This allows zero-downtime deployments.

### 14. Why did you use Terraform instead of CloudFormation?
**Answer:** Terraform provides cloud-agnostic infrastructure as code, making it easier to potentially migrate to other clouds. It has a more intuitive HCL syntax, better state management, and a larger community with extensive modules. The plan/apply workflow gives clear visibility into changes before execution, reducing deployment risks.

### 15. How do you ensure data durability and backup?
**Answer:** DynamoDB provides automatic replication across three AZs with 99.999999999% durability. S3 versioning is enabled, allowing recovery from accidental deletions or overwrites. DynamoDB point-in-time recovery could be enabled for additional protection. The lifecycle policies ensure data is preserved in Glacier before final deletion, providing a recovery window.
