"""
Load Testing Script for CRUD Application
Tests ALB distribution and Auto Scaling behavior
"""
from locust import HttpUser, task, between
import uuid
import random


class CrudAppLoadTest(HttpUser):
    """
    Simulates user behavior for CRUD operations
    """
    wait_time = between(1, 3)  # Wait 1-3 seconds between tasks
    
    def on_start(self):
        """Called when a user starts"""
        self.created_items = []
    
    @task(5)
    def list_items(self):
        """GET /api/items - Most common operation (weight: 5)"""
        with self.client.get("/api/items", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(2)
    def create_item(self):
        """POST /api/items - Create new items (weight: 2)"""
        item_id = str(uuid.uuid4())
        payload = {
            "id": item_id,
            "name": f"load-test-{random.randint(1000, 9999)}",
            "description": f"Testing load at {random.choice(['low', 'medium', 'high'])} intensity"
        }
        
        with self.client.post("/api/items", json=payload, catch_response=True) as response:
            if response.status_code in [200, 201]:
                self.created_items.append(item_id)
                response.success()
            else:
                response.failure(f"Create failed with {response.status_code}")
    
    @task(1)
    def get_single_item(self):
        """GET /api/items/{id} - Get specific item (weight: 1)"""
        if self.created_items:
            item_id = random.choice(self.created_items)
            with self.client.get(f"/api/items/{item_id}", catch_response=True) as response:
                if response.status_code == 200:
                    response.success()
                elif response.status_code == 404:
                    response.success()  # Item might have been deleted
                else:
                    response.failure(f"Got status code {response.status_code}")
    
    @task(1)
    def update_item(self):
        """PUT /api/items/{id} - Update existing item (weight: 1)"""
        if self.created_items:
            item_id = random.choice(self.created_items)
            payload = {
                "name": f"updated-{random.randint(1000, 9999)}",
                "description": "Updated during load test"
            }
            
            with self.client.put(f"/api/items/{item_id}", json=payload, catch_response=True) as response:
                if response.status_code in [200, 404]:
                    response.success()
                else:
                    response.failure(f"Update failed with {response.status_code}")
    
    @task(1)
    def delete_item(self):
        """DELETE /api/items/{id} - Delete item (weight: 1)"""
        if self.created_items:
            item_id = self.created_items.pop()
            with self.client.delete(f"/api/items/{item_id}", catch_response=True) as response:
                if response.status_code in [200, 204, 404]:
                    response.success()
                else:
                    response.failure(f"Delete failed with {response.status_code}")


class ReadHeavyUser(HttpUser):
    """
    Simulates read-heavy workload (for testing ALB distribution)
    """
    wait_time = between(0.5, 2)
    
    @task
    def read_only(self):
        """Only performs GET operations"""
        self.client.get("/api/items")


class WriteHeavyUser(HttpUser):
    """
    Simulates write-heavy workload (for testing Auto Scaling)
    """
    wait_time = between(1, 2)
    
    @task
    def write_operations(self):
        """Performs write operations to increase CPU load"""
        item_id = str(uuid.uuid4())
        payload = {
            "id": item_id,
            "name": f"write-test-{uuid.uuid4()}",
            "description": "Heavy write operation" * 10  # Larger payload
        }
        self.client.post("/api/items", json=payload)
