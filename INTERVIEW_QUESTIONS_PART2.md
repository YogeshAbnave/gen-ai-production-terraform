# Interview Questions - Part 2: Application & AI Integration

## Application Development Questions (16-30)

### 16. Walk me through the application flow for creating an assignment.
**Answer:** A teacher enters text in the Streamlit interface. The application calls Bedrock's Titan Text model to generate 10 questions and answers using a structured prompt. Simultaneously, it calls Titan Image Generator to create a visual representation. The image is optimized (resized to max 1024x1024, converted to WebP, compressed) and uploaded to S3. The assignment data (text, questions, S3 key, CloudFront URL) is stored in DynamoDB with a unique assignment ID. The entire process includes retry logic and error handling.

### 17. How did you handle AWS Bedrock content filters?
**Answer:** Bedrock's content filters sometimes block legitimate educational content. I implemented a sanitization function that adds educational context to prompts ("Educational illustration showing..."), truncates overly long prompts to 200 characters, and implements graceful fallback. If image generation fails due to content filters, the application continues without the image, storing "no image created" in the database and showing a user-friendly message.

### 18. Explain your AI grading system for student answers.
**Answer:** I use semantic similarity scoring with Amazon Titan Embeddings. Both the correct answer and student's answer are converted to 1024-dimensional embedding vectors. I calculate cosine distance between vectors using scipy.spatial.distance. The score is (1 - distance) * 100, giving a 0-100 score. This captures semantic meaning rather than exact word matching, so "big" and "large" score similarly.

### 19. How do you handle multiple AI model formats in Bedrock?
**Answer:** Different Bedrock models have different request/response formats. I implemented conditional logic checking the model ID: Claude uses anthropic_version with messages array, Titan Text uses inputText with textGenerationConfig, and Nova uses inferenceConfig with messages. The response parsing also adapts to each model's output structure. This makes the application flexible to use different models.

### 20. What error handling strategies did you implement?
**Answer:** Multiple layers: Try-catch blocks around all AWS API calls with specific ClientError handling, retry logic with exponential backoff for S3 uploads (3 attempts), correlation IDs for error tracking across services, user-friendly error messages in the UI instead of technical stack traces, graceful degradation (continue without images if generation fails), and comprehensive logging for debugging production issues.

### 21. How do you manage environment configuration?
**Answer:** I use environment variables for all configuration: AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, DYNAMODB_TABLE_NAME, S3_BUCKET_NAME, CLOUDFRONT_DOMAIN, and Bedrock model IDs. These are set in the EC2 user data script during instance launch. This allows easy configuration changes without code modifications and supports different environments (dev, staging, production).

### 22. Explain your image optimization process.
**Answer:** The ImageOptimizer class performs three optimizations: converts PNG to WebP format (better compression), resizes images to maximum 1024x1024 while preserving aspect ratio (reduces file size), and applies 85% quality compression. This typically achieves 30%+ size reduction, reducing S3 storage costs and CloudFront bandwidth. If optimization fails, it falls back to the original image.

### 23. How do you handle concurrent users?
**Answer:** The application is stateless, allowing horizontal scaling. Each EC2 instance runs independently with its own Streamlit process. The ALB distributes requests across instances using round-robin. DynamoDB handles concurrent writes with automatic conflict resolution. S3 supports high concurrency natively. Session state is managed client-side by Streamlit, eliminating the need for sticky sessions.

### 24. What is your data model in DynamoDB?
**Answer:** I use a single-table design with a composite key strategy. The primary key is "id". For assignments: id = assignment_id, with attributes for teacher_id, prompt, s3_image_name, question_answers (JSON), and record_type = "assignment". For student answers: id = "answer_{student_id}_{assignment_id}_{question_id}", with attributes for answer text, score, and record_type = "answer". This allows efficient queries and reduces costs.

### 25. How do you prevent duplicate submissions?
**Answer:** For student answers, I use a composite ID (student_id + assignment_id + question_id) as the primary key. Before saving, I check if a record exists and only update if the new score is higher than the existing score. This ensures students can retry questions to improve their scores while maintaining their best performance.

### 26. Explain your S3 upload strategy.
**Answer:** The S3ImageService implements retry logic with exponential backoff (3 attempts with 1s, 2s, 4s delays). Each upload includes metadata: Content-Type for proper browser rendering, Cache-Control for CloudFront caching behavior, and custom metadata for tracking. Images are stored with a structured naming convention: generated_images/{assignment_id}.png. Correlation IDs track uploads across logs.

### 27. How do you handle missing or deleted images?
**Answer:** The application checks if s3_image_name exists and is not "no image created". It attempts to generate a CloudFront URL or S3 pre-signed URL. If the image doesn't exist in S3 (404 error), it displays a placeholder message "📷 No image available" instead of breaking the page. This graceful degradation ensures the application remains functional even with data inconsistencies.

### 28. What testing strategies did you implement?
**Answer:** Multiple levels: Unit tests for individual functions (S3 upload, image optimization, DynamoDB operations), property-based tests using Hypothesis for testing across random inputs (image compression ratios, upload idempotence), integration tests for end-to-end flows (create assignment → upload → retrieve), and load testing with Locust to validate auto-scaling behavior under 50+ concurrent users.

### 29. How do you generate unique assignment IDs?
**Answer:** I use a combination of epoch time and random number: (current_time_ms - 1670000000000) * 1000 + random(0-999). This creates a unique, sortable ID that's unlikely to collide. The epoch offset reduces the number size, and the random component handles multiple assignments created in the same millisecond. This is more efficient than UUIDs for DynamoDB.

### 30. Explain your prompt engineering for question generation.
**Answer:** The prompt is carefully structured: clear instructions to generate exactly 10 questions, explicit JSON format specification with example structure, rules for question quality (based on context, clear answers), emphasis on returning ONLY JSON without explanatory text, and temperature/top_p parameters tuned for consistent output. This reduces parsing errors and ensures reliable question generation.
