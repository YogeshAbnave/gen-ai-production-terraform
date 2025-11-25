"""
Load Testing Script for Image Operations
Tests S3 upload/download, CloudFront caching, and Auto Scaling behavior
"""
from locust import HttpUser, task, between, events
import uuid
import random
import time
import json
import base64
from io import BytesIO


class ImageLoadTest(HttpUser):
    """
    Simulates teacher and student behavior with image operations
    Tests image generation, S3 upload, and CloudFront retrieval
    """
    wait_time = between(2, 5)  # Wait 2-5 seconds between tasks
    
    def on_start(self):
        """Called when a user starts"""
        self.created_assignments = []
        self.assignment_images = {}
    
    @task(3)
    def create_assignment_with_image(self):
        """
        POST /api/assignments - Create assignment with image
        Simulates: Bedrock image generation → S3 upload → MongoDB save
        Weight: 3 (moderate frequency)
        """
        assignment_id = str(uuid.uuid4())
        prompt = f"A {random.choice(['mountain', 'ocean', 'forest', 'desert', 'city'])} landscape at {random.choice(['sunrise', 'sunset', 'noon', 'midnight'])}"
        
        # Simulate image generation payload
        payload = {
            "assignment_id": assignment_id,
            "teacher_id": "load-test-teacher",
            "prompt": prompt,
            "generate_image": True,
            "questions": [
                {"id": f"q{i}", "question": f"Question {i}?", "answer": f"Answer {i}"}
                for i in range(1, 6)
            ]
        }
        
        start_time = time.time()
        with self.client.post(
            "/api/assignments",
            json=payload,
            catch_response=True,
            name="/api/assignments [CREATE with image]"
        ) as response:
            total_time = (time.time() - start_time) * 1000  # Convert to ms
            
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    s3_key = data.get("s3_image_key")
                    cloudfront_url = data.get("cloudfront_url")
                    
                    if s3_key and cloudfront_url:
                        self.created_assignments.append(assignment_id)
                        self.assignment_images[assignment_id] = cloudfront_url
                        response.success()
                        
                        # Log S3 upload time separately
                        events.request.fire(
                            request_type="S3",
                            name="S3 Upload",
                            response_time=total_time,
                            response_length=len(response.content),
                            exception=None,
                            context={}
                        )
                    else:
                        response.failure("Missing S3 key or CloudFront URL in response")
                except Exception as e:
                    response.failure(f"Failed to parse response: {e}")
            else:
                response.failure(f"Create failed with status {response.status_code}")
    
    @task(5)
    def view_assignment_with_image(self):
        """
        GET /api/assignments/{id} - View assignment and retrieve image
        Simulates: Student viewing assignment → CloudFront image retrieval
        Weight: 5 (most common operation)
        """
        if not self.created_assignments:
            return
        
        assignment_id = random.choice(self.created_assignments)
        
        # Get assignment metadata
        with self.client.get(
            f"/api/assignments/{assignment_id}",
            catch_response=True,
            name="/api/assignments/{id} [VIEW]"
        ) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    cloudfront_url = data.get("cloudfront_url")
                    
                    if cloudfront_url:
                        # Retrieve image from CloudFront
                        self._download_image_from_cloudfront(cloudfront_url)
                        response.success()
                    else:
                        response.success()  # Assignment without image is valid
                except Exception as e:
                    response.failure(f"Failed to parse response: {e}")
            elif response.status_code == 404:
                response.success()  # Assignment might have been deleted
            else:
                response.failure(f"View failed with status {response.status_code}")
    
    @task(1)
    def list_assignments(self):
        """
        GET /api/assignments - List all assignments (no images)
        Weight: 1 (less frequent)
        """
        with self.client.get(
            "/api/assignments",
            catch_response=True,
            name="/api/assignments [LIST]"
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"List failed with status {response.status_code}")
    
    def _download_image_from_cloudfront(self, cloudfront_url):
        """
        Download image from CloudFront and measure latency
        This tests CloudFront caching and S3 retrieval performance
        """
        start_time = time.time()
        
        try:
            # Use requests directly to measure CloudFront performance
            import requests
            img_response = requests.get(cloudfront_url, timeout=10)
            total_time = (time.time() - start_time) * 1000  # Convert to ms
            
            if img_response.status_code == 200:
                # Log CloudFront download time
                events.request.fire(
                    request_type="CloudFront",
                    name="Image Download",
                    response_time=total_time,
                    response_length=len(img_response.content),
                    exception=None,
                    context={}
                )
            else:
                events.request.fire(
                    request_type="CloudFront",
                    name="Image Download",
                    response_time=total_time,
                    response_length=0,
                    exception=Exception(f"Status {img_response.status_code}"),
                    context={}
                )
        except Exception as e:
            total_time = (time.time() - start_time) * 1000
            events.request.fire(
                request_type="CloudFront",
                name="Image Download",
                response_time=total_time,
                response_length=0,
                exception=e,
                context={}
            )


class ImageHeavyUser(HttpUser):
    """
    Simulates heavy image generation workload
    Used to test auto-scaling behavior under CPU load
    """
    wait_time = between(1, 3)
    
    @task
    def create_multiple_images(self):
        """
        Rapidly create assignments with images to trigger auto-scaling
        """
        for _ in range(3):  # Create 3 assignments per task
            assignment_id = str(uuid.uuid4())
            payload = {
                "assignment_id": assignment_id,
                "teacher_id": "load-test-heavy",
                "prompt": f"Complex scene with {random.randint(5, 20)} elements",
                "generate_image": True,
                "questions": [{"id": f"q{i}", "question": f"Q{i}", "answer": f"A{i}"} for i in range(10)]
            }
            
            self.client.post(
                "/api/assignments",
                json=payload,
                name="/api/assignments [HEAVY CREATE]"
            )


class CacheTestUser(HttpUser):
    """
    Tests CloudFront caching by repeatedly requesting same images
    Should see improved latency on subsequent requests
    """
    wait_time = between(0.5, 1.5)
    
    def on_start(self):
        """Get a list of existing assignments"""
        response = self.client.get("/api/assignments")
        if response.status_code == 200:
            assignments = response.json()
            self.image_urls = [
                a.get("cloudfront_url") 
                for a in assignments 
                if a.get("cloudfront_url")
            ]
        else:
            self.image_urls = []
    
    @task
    def request_cached_image(self):
        """
        Repeatedly request same images to test cache hit ratio
        """
        if not self.image_urls:
            return
        
        # Pick same image multiple times to test caching
        url = random.choice(self.image_urls[:5])  # Focus on first 5 images
        
        start_time = time.time()
        try:
            import requests
            response = requests.get(url, timeout=5)
            total_time = (time.time() - start_time) * 1000
            
            # Check for cache hit via headers
            cache_status = response.headers.get("X-Cache", "Unknown")
            
            events.request.fire(
                request_type="CloudFront-Cache",
                name=f"Cached Image [{cache_status}]",
                response_time=total_time,
                response_length=len(response.content) if response.status_code == 200 else 0,
                exception=None if response.status_code == 200 else Exception(f"Status {response.status_code}"),
                context={"cache_status": cache_status}
            )
        except Exception as e:
            total_time = (time.time() - start_time) * 1000
            events.request.fire(
                request_type="CloudFront-Cache",
                name="Cached Image [Error]",
                response_time=total_time,
                response_length=0,
                exception=e,
                context={}
            )
