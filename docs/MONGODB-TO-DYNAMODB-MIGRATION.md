# MongoDB to DynamoDB Migration

## Overview
Migrated the application from MongoDB to DynamoDB for production use, eliminating the need for MongoDB installation and maintenance on EC2 instances.

## Changes Made

### 1. Create Assignments Page (`src/pages/1_Create_Assignments.py`)
**Removed:**
- `pymongo` import and `MongoClient`
- MongoDB connection setup
- `questions_collection` reference

**Added:**
- DynamoDB client and resource setup
- `assignments_table` using boto3 DynamoDB resource
- `insert_record_to_dynamodb()` function

**Key Changes:**
- Assignments now stored with `id` as primary key (same as `assignment_id`)
- Added `record_type: "assignment"` field to distinguish from answers
- All fields stored as strings for DynamoDB compatibility

### 2. Show Assignments Page (`src/pages/2_Show_Assignments.py`)
**Removed:**
- `pymongo` import and `MongoClient`
- MongoDB connection
- `get_records_from_mongodb()` function

**Added:**
- DynamoDB resource setup
- `get_records_from_dynamodb()` function with pagination support
- Filtering by `record_type = "assignment"`

### 3. Complete Assignments Page (`src/pages/3_Complete_Assignments.py`)
**Removed:**
- `pymongo` import, `MongoClient`, and `DESCENDING`
- MongoDB collections (`assignments_collection`, `answers_collection`)
- MongoDB-specific query functions

**Added:**
- DynamoDB resource setup
- `get_assignments_from_dynamodb()` - Fetches assignments with pagination
- `get_answer_record_from_dynamodb()` - Gets student answer by composite key
- `save_answer_record()` - Saves/updates answer with highest score logic
- `get_high_score_answer_records_from_dynamodb()` - Gets top scores with client-side sorting

**Key Changes:**
- Answer IDs use format: `answer_{student_id}_{assignment_id}_{question_id}`
- Answers stored with `record_type: "answer"`
- Score comparison done in application code (DynamoDB doesn't have `$max` operator)
- Sorting done client-side after scan

### 4. Dependencies (`src/requirements.txt`)
**Removed:**
- `pymongo`

## DynamoDB Table Structure

### Table Name
`app-data-table` (configurable via `DYNAMODB_TABLE_NAME` env var)

### Primary Key
- `id` (String) - Partition key

### Record Types

#### Assignment Records
```json
{
  "id": "1732612345678",
  "assignment_id": "1732612345678",
  "teacher_id": "CloudAge-User",
  "prompt": "A serene mountain landscape",
  "s3_image_name": "generated_images/1732612345678.png",
  "question_answers": "[{...}]",
  "created_at": "1732612345.678",
  "record_type": "assignment"
}
```

#### Answer Records
```json
{
  "id": "answer_CloudAge-User_1732612345678_1",
  "student_id": "CloudAge-User",
  "assignment_id": "1732612345678",
  "question_id": "1",
  "assignment_question_id": "1732612345678_1",
  "answer": "Student's answer text",
  "score": "85",
  "record_type": "answer"
}
```

## Environment Variables

### Required
- `AWS_REGION` - AWS region (default: "us-east-1")
- `DYNAMODB_TABLE_NAME` - DynamoDB table name (default: "app-data-table")

### Removed
- `MONGO_URI` - No longer needed

## Terraform Configuration

The DynamoDB table is already provisioned in `infrastructure/dynamodb.tf`:
```hcl
resource "aws_dynamodb_table" "main" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
```

## IAM Permissions

The EC2 IAM role already has DynamoDB permissions in `infrastructure/iam.tf`:
```json
{
  "Effect": "Allow",
  "Action": [
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:UpdateItem",
    "dynamodb:DeleteItem",
    "dynamodb:Query",
    "dynamodb:Scan"
  ],
  "Resource": "arn:aws:dynamodb:*:*:table/app-data-table"
}
```

## Migration Notes

### Data Migration
If you have existing MongoDB data, you'll need to migrate it manually:
1. Export data from MongoDB
2. Transform to DynamoDB format (add `id` and `record_type` fields)
3. Import to DynamoDB using AWS CLI or SDK

### Differences from MongoDB

1. **No Transactions**: DynamoDB doesn't support multi-document transactions like MongoDB
2. **No $max Operator**: Score comparison done in application code
3. **Client-Side Sorting**: Leaderboard sorting done after fetching data
4. **Scan Operations**: Used for filtering by `record_type` (consider adding GSI for production)

### Performance Considerations

1. **Scan Operations**: Current implementation uses `scan` which reads entire table
   - For production, consider adding a Global Secondary Index (GSI) on `record_type`
   - Or use separate tables for assignments and answers

2. **Pagination**: Implemented for large result sets to avoid memory issues

3. **Eventual Consistency**: DynamoDB reads are eventually consistent by default
   - Use `ConsistentRead=True` if strong consistency is required

## Testing

After deployment, verify:
1. ✅ Create new assignment - should save to DynamoDB
2. ✅ View assignments list - should load from DynamoDB
3. ✅ Submit answers - should save to DynamoDB
4. ✅ View leaderboard - should show top scores
5. ✅ No MongoDB connection errors

## Rollback Plan

If issues occur:
1. Revert code changes
2. Reinstall `pymongo` in requirements.txt
3. Ensure MongoDB is running on EC2 instances
4. Redeploy application

## Benefits

✅ No MongoDB installation/maintenance required
✅ Fully managed AWS service
✅ Auto-scaling with pay-per-request billing
✅ Better integration with AWS ecosystem
✅ Simplified infrastructure
