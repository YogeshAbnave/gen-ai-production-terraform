# Interview Questions - Part 3: DevOps & Performance

## DevOps & CI/CD Questions (31-45)

### 31. Describe your CI/CD pipeline.
**Answer:** GitHub Actions triggers on push to main branch. The workflow: checks out code, configures AWS credentials from GitHub secrets, builds the frontend (if applicable), installs Python dependencies, retrieves EC2 instance IPs from the Auto Scaling Group, SSHs into each instance using the private key, deploys code via rsync, restarts Streamlit and NGINX services, and verifies health checks. The entire process takes 3-5 minutes.

### 32. How do you manage secrets in your deployment?
**Answer:** Secrets are stored as GitHub repository secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, EC2_PRIVATE_KEY). The deployment script retrieves these securely during workflow execution. On EC2 instances, credentials are provided via IAM roles (no hardcoded keys). The Terraform state file is stored locally (could be moved to S3 with encryption for team collaboration).

### 33. What is your infrastructure deployment process?
**Answer:** First-time deployment: run terraform init to initialize providers, terraform plan to preview changes, terraform apply to create infrastructure (VPC, subnets, ALB, ASG, DynamoDB, S3, CloudFront, IAM roles). This takes 5-7 minutes. Terraform outputs provide the ALB DNS and S3 bucket name. For updates, terraform plan shows only changed resources, minimizing deployment risk.

### 34. How do you handle infrastructure updates without downtime?
**Answer:** Terraform's state management allows incremental updates. For EC2 changes, I update the launch template, which triggers a rolling replacement in the ASG. The ALB continues routing to old instances until new ones pass health checks. For application updates, GitHub Actions deploys to instances one at a time, allowing the ALB to route around instances being updated.

### 35. Explain your load testing strategy.
**Answer:** I use Locust to simulate realistic user behavior with three test classes: CrudAppLoadTest (mixed operations with weighted tasks), ReadHeavyUser (GET-only for ALB testing), and WriteHeavyUser (POST-heavy for auto-scaling testing). Tests run with 50 concurrent users, 5 users/second spawn rate, measuring p50/p95/p99 latencies, error rates, and requests per second. This validates auto-scaling triggers.

### 36. What metrics do you monitor in production?
**Answer:** CloudWatch metrics: EC2 CPU utilization (auto-scaling trigger), ALB request count and latency, ALB healthy/unhealthy instance count, DynamoDB read/write capacity and throttles, S3 bucket size and request count, CloudFront cache hit ratio and request count, and application-level errors logged to CloudWatch Logs. Alarms notify on anomalies.

### 37. How do you troubleshoot production issues?
**Answer:** Systematic approach: check CloudWatch dashboards for metric anomalies, review CloudWatch Logs for application errors (filtered by correlation ID), SSH into EC2 instances to check service status (systemctl status), review NGINX and application logs (journalctl), verify security group rules and IAM permissions, test connectivity to DynamoDB/S3/Bedrock, and use AWS X-Ray for distributed tracing if needed.

### 38. What is your disaster recovery plan?
**Answer:** Multi-AZ deployment provides automatic failover. For complete region failure: Terraform code can recreate infrastructure in another region within 10 minutes, DynamoDB can be backed up with point-in-time recovery or on-demand backups, S3 cross-region replication could be enabled for critical images, and the application code is in GitHub for quick redeployment. RTO: 15 minutes, RPO: 5 minutes.

### 39. How do you optimize costs?
**Answer:** Multiple strategies: DynamoDB pay-per-request (no idle capacity costs), S3 lifecycle policies (transition to cheaper storage classes), CloudFront reduces S3 data transfer costs, Auto Scaling reduces EC2 costs during low traffic (scales down to 2 instances), t2.micro instances for development, and spot instances could be used for non-critical workloads. Current monthly cost: ~$50-100.

### 40. Explain your logging strategy.
**Answer:** Application logs go to CloudWatch Logs with structured logging (timestamp, level, correlation ID, message). Each AWS service interaction is logged with request/response details. Errors include full context for debugging. Logs are retained for 30 days. For production, I'd implement log aggregation with CloudWatch Insights queries for pattern analysis and alerting on error rate spikes.

### 41. How do you ensure code quality?
**Answer:** Multiple practices: Python type hints for static analysis, comprehensive error handling with specific exception types, unit tests for critical functions, property-based tests for edge cases, integration tests for end-to-end flows, code reviews before merging, linting with pylint/flake8, and load testing before production deployment. GitHub Actions could run tests automatically on each commit.

### 42. What is your rollback strategy?
**Answer:** For infrastructure: Terraform state allows reverting to previous configuration with terraform apply of old code. For application: GitHub Actions can redeploy previous commit, or manually SSH and checkout previous code version. The ALB health checks prevent broken deployments from receiving traffic. DynamoDB versioning allows data recovery. Typical rollback time: 5 minutes.

### 43. How do you handle database migrations?
**Answer:** DynamoDB is schema-less, simplifying migrations. For adding new attributes, I use conditional writes to add fields only if missing. For changing data structure, I implement dual-write (write to both old and new format) then migrate existing data with a script, then remove old format. The application handles both formats during transition, ensuring zero downtime.

### 44. What performance optimizations did you implement?
**Answer:** Multiple layers: CloudFront CDN for image delivery (70% latency reduction), image optimization (30% size reduction), DynamoDB with efficient key design (single-digit ms latency), S3 pre-signed URLs (avoid proxy through application), Streamlit caching for expensive operations, and async operations where possible. Load testing validates p95 latency <500ms for all operations.

### 45. How do you manage different environments (dev/staging/prod)?
**Answer:** Terraform workspaces or separate state files for each environment. Environment-specific variables in terraform.tfvars files. GitHub Actions with environment-specific secrets. Different AWS accounts or VPCs for isolation. Naming conventions include environment prefix (dev-crud-app-alb). This allows testing infrastructure changes in dev before production deployment.
