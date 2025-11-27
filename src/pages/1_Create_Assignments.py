import json, logging, math, random, time, base64, os
from io import BytesIO

import boto3, numpy as np, streamlit as st
from PIL import Image
from botocore.exceptions import ClientError
from components.Parameter_store import S3_BUCKET_NAME
from pymongo import MongoClient

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS + MongoDB setup
aws_region = os.getenv("AWS_REGION", "us-east-1")
mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
client = MongoClient(mongo_uri)

session = boto3.Session(
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=aws_region,
)

print("AWS session:", session)

bedrock_client = session.client("bedrock-runtime")
db = client["assignments_db"]
questions_collection = db["assignments"]

user_name = "CloudAge-User"
# Use environment variables for model IDs with fallback to Amazon Titan models (no marketplace subscription needed)
text_model_id = os.getenv("BEDROCK_TEXT_MODEL_ID", "amazon.titan-text-express-v1")
image_model_id = os.getenv("BEDROCK_IMAGE_MODEL_ID", "amazon.titan-image-generator-v1")

# Session state
if "input-text" not in st.session_state:
    st.session_state["input-text"] = None
if "question_answers" not in st.session_state:
    st.session_state["question_answers"] = None


# ---------------- Helper Functions ---------------- #


def parse_text_to_lines(text):
    """Parse JSON-like text from model into Python object"""
    # Remove markdown code blocks and extra whitespace
    text = text.replace("```json", "").replace("```", "").strip()
    
    # Remove any text before the first [ and after the last ]
    start_idx = text.find('[')
    end_idx = text.rfind(']')
    
    if start_idx != -1 and end_idx != -1:
        text = text[start_idx:end_idx + 1]
    else:
        st.error("No JSON array found in response")
        st.text_area("Raw response for debugging:", text, height=200)
        return []
    
    try:
        parsed = json.loads(text)
        
        # Validate the structure
        if not isinstance(parsed, list):
            st.error("Response is not a JSON array")
            return []
        
        # Validate each item has required fields
        for item in parsed:
            if not all(key in item for key in ["Id", "Question", "Answer"]):
                st.warning(f"Item missing required fields: {item}")
        
        return parsed
    except json.JSONDecodeError as e:
        st.error(f"Failed to parse JSON response: {e}")
        st.text_area("Raw response for debugging:", text, height=200)
        
        # Show helpful error message
        st.info("💡 Tip: The AI model may need to be configured properly. Check the Bedrock setup guide in docs/BEDROCK-SETUP.md")
        return []


def query_generate_questions_answers_endpoint(input_text):
    """Call Bedrock text model to generate Q&A"""
    prompt = f"""Based on the following context, generate exactly 10 questions and answers for students.

Context:
{input_text}

IMPORTANT: Return ONLY a valid JSON array. Do not include any explanatory text before or after the JSON.

Required format (return ONLY this, nothing else):
[
  {{"Id": 1, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 2, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 3, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 4, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 5, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 6, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 7, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 8, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 9, "Question": "Your question here?", "Answer": "Your answer here"}},
  {{"Id": 10, "Question": "Your question here?", "Answer": "Your answer here"}}
]

Rules:
- Each question must be based on the provided context
- Each answer must be clear and correct
- Use proper JSON formatting with double quotes
- Return ONLY the JSON array, no additional text"""
    
    # Support different model formats
    if "anthropic.claude" in text_model_id:
        # Claude format
        input_data = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": [{"role": "user", "content": prompt}],
        }
    elif "amazon.titan-text" in text_model_id:
        # Titan Text format
        input_data = {
            "inputText": prompt,
            "textGenerationConfig": {
                "maxTokenCount": 2000,
                "temperature": 0.7,
                "topP": 0.9,
            }
        }
    else:
        # Nova format
        input_data = {
            "inferenceConfig": {"max_new_tokens": 2000},
            "messages": [{"role": "user", "content": [{"text": prompt}]}],
        }
    
    try:
        qa_response = bedrock_client.invoke_model(
            modelId=text_model_id,
            body=json.dumps(input_data).encode("utf-8"),
            accept="application/json",
            contentType="application/json",
        )
    except (ClientError, Exception) as e:
        st.error(f"Can't invoke model {text_model_id}. Reason: {e}")
        return []

    try:
        response_body = json.loads(qa_response.get("body").read().decode())
        
        # Parse response based on model type
        if "anthropic.claude" in text_model_id:
            response_text = response_body["content"][0]["text"]
        elif "amazon.titan-text" in text_model_id:
            response_text = response_body["results"][0]["outputText"]
        else:
            # Nova format
            response_text = response_body["output"]["message"]["content"][0]["text"]
        
        # Log the raw response for debugging
        logger.info(f"Model response (first 500 chars): {response_text[:500]}")
        
        return parse_text_to_lines(response_text)
    except (KeyError, IndexError, json.JSONDecodeError) as e:
        st.error(f"Error parsing model response: {e}")
        st.text_area("Raw response body:", str(response_body), height=200)
        return []


def query_generate_image_endpoint(input_text):
    """Generate an image using Bedrock image model"""
    input_body = json.dumps(
        {
            "taskType": "TEXT_IMAGE",
            "textToImageParams": {"text": f"An image of {input_text}"},
            "imageGenerationConfig": {
                "numberOfImages": 1,
                "height": 1024,
                "width": 1024,
                "cfgScale": 8.0,
                "seed": 0,
            },
        }
    )
    titan_image_api_response = bedrock_client.invoke_model(
        body=input_body,
        modelId=image_model_id,
        accept="application/json",
        contentType="application/json",
    )
    response_body = json.loads(titan_image_api_response.get("body").read())
    base64_image = response_body.get("images")[0]
    image_bytes = base64.b64decode(base64_image.encode("ascii"))
    return Image.open(BytesIO(image_bytes))


def generate_assignment_id_key():
    epoch = round(time.time() * 1000) - 1670000000000
    rand_id = math.floor(random.random() * 999)
    return str((epoch * 1000) + rand_id)


def ensure_bucket_exists(s3_client, bucket_name):
    """Create S3 bucket if it doesn't exist"""
    try:
        s3_client.head_bucket(Bucket=bucket_name)
        return True
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == '404':
            # Bucket doesn't exist, create it
            try:
                region = aws_region
                if region == 'us-east-1':
                    s3_client.create_bucket(Bucket=bucket_name)
                else:
                    s3_client.create_bucket(
                        Bucket=bucket_name,
                        CreateBucketConfiguration={'LocationConstraint': region}
                    )
                
                # Enable versioning
                s3_client.put_bucket_versioning(
                    Bucket=bucket_name,
                    VersioningConfiguration={'Status': 'Enabled'}
                )
                
                # Enable encryption
                s3_client.put_bucket_encryption(
                    Bucket=bucket_name,
                    ServerSideEncryptionConfiguration={
                        'Rules': [{'ApplyServerSideEncryptionByDefault': {'SSEAlgorithm': 'AES256'}}]
                    }
                )
                
                # Block public access
                s3_client.put_public_access_block(
                    Bucket=bucket_name,
                    PublicAccessBlockConfiguration={
                        'BlockPublicAcls': True,
                        'IgnorePublicAcls': True,
                        'BlockPublicPolicy': True,
                        'RestrictPublicBuckets': True
                    }
                )
                
                st.success(f"✅ Created S3 bucket: {bucket_name}")
                return True
            except ClientError as create_error:
                st.error(f"Failed to create bucket {bucket_name}: {create_error}")
                return False
        else:
            st.error(f"Error checking bucket {bucket_name}: {e}")
            return False


def load_file_to_s3(file_name, object_name):
    """Upload file to S3, creating bucket if needed"""
    s3_client = session.client("s3")
    
    # Ensure bucket exists
    if not ensure_bucket_exists(s3_client, S3_BUCKET_NAME):
        return False
    
    try:
        s3_client.upload_file(file_name, S3_BUCKET_NAME, object_name)
        return True
    except ClientError as e:
        error_msg = str(e)
        st.error(f"Failed to upload {file_name} to {S3_BUCKET_NAME}/{object_name}: {error_msg}")
        logging.error(f"S3 upload error: {error_msg}")
        return False


def insert_record_to_mongodb(assignment_id, prompt, s3_image_name, data):
    """Insert assignment record into MongoDB"""
    record = {
        "assignment_id": assignment_id,
        "teacher_id": user_name,
        "prompt": prompt,
        "s3_image_name": s3_image_name,
        "question_answers": data,
        "created_at": time.time(),
    }
    result = questions_collection.insert_one(record)
    return result.inserted_id


# ---------------- Streamlit UI ---------------- #

st.set_page_config(page_title="Create Assignments", page_icon=":pencil:", layout="wide")

st.sidebar.header("Create Assignments")
st.markdown("# Create Assignments")

text = st.text_area("Input Text")
if text and text != st.session_state.get("input-text"):
    try:
        if image_model_id != "<model-id>":
            image = query_generate_image_endpoint(text)
            image.save("temp-create.png")
            st.session_state["input-text"] = text

        questions_answers = query_generate_questions_answers_endpoint(text)
        st.session_state["question_answers"] = questions_answers
    except Exception as ex:
        st.error(f"Error generating assignment: {ex}")

if st.session_state.get("question_answers"):
    st.markdown("## Generated Questions and Answers")
    st.text_area(
        "Questions and Answers",
        json.dumps(st.session_state["question_answers"], indent=4),
        height=320,
        label_visibility="collapsed",
    )

if st.button("Save Assignment"):
    if not st.session_state.get("question_answers"):
        st.error("Please generate questions and answers first!")
    elif not text:
        st.error("Please enter input text first!")
    else:
        try:
            assignment_id = generate_assignment_id_key()
            questions_answers = json.dumps(
                st.session_state["question_answers"], indent=4
            )

            if os.path.exists("temp-create.png"):
                object_name = f"generated_images/{assignment_id}.png"
                load_file_to_s3("temp-create.png", object_name)
            else:
                object_name = "no image created"

            insert_record_to_mongodb(
                assignment_id, text, object_name, questions_answers
            )
            st.success(f"Assignment saved successfully with ID: {assignment_id}")
        except Exception as ex:
            st.error(f"Error saving assignment: {ex}")
