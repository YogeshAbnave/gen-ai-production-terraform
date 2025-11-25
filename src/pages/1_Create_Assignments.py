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
# Use environment variables for model IDs with fallback to widely available models
text_model_id = os.getenv("BEDROCK_TEXT_MODEL_ID", "anthropic.claude-3-sonnet-20240229-v1:0")
image_model_id = os.getenv("BEDROCK_IMAGE_MODEL_ID", "amazon.titan-image-generator-v1")

# Session state
if "input-text" not in st.session_state:
    st.session_state["input-text"] = None
if "question_answers" not in st.session_state:
    st.session_state["question_answers"] = None


# ---------------- Helper Functions ---------------- #


def parse_text_to_lines(text):
    """Parse JSON-like text from model into Python object"""
    text = text.replace("```json\n", "").replace("\n```", "")
    return json.loads(text)


def query_generate_questions_answers_endpoint(input_text):
    """Call Bedrock text model to generate Q&A"""
    prompt = f"""{input_text}

Using the above context, please generate ten questions and answers you could ask students about this information.
Format the output as a JSON array with objects containing "Id", "Question", and "Answer" keys.

Example format:
[
  {{"Id": 1, "Question": "What is...", "Answer": "..."}},
  {{"Id": 2, "Question": "How does...", "Answer": "..."}}
]

Make sure each question is based on the provided context, and the answers are clear and correct."""
    
    # Support both Claude and Nova model formats
    if "anthropic.claude" in text_model_id:
        input_data = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": [{"role": "user", "content": prompt}],
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

    response_body = json.loads(qa_response.get("body").read().decode())
    
    # Parse response based on model type
    if "anthropic.claude" in text_model_id:
        response_text = response_body["content"][0]["text"]
    else:
        # Nova format
        response_text = response_body["output"]["message"]["content"][0]["text"]
    
    return parse_text_to_lines(response_text)


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


def load_file_to_s3(file_name, object_name):
    """Upload file to S3"""
    s3_client = session.client("s3")
    try:
        s3_client.upload_file(file_name, S3_BUCKET_NAME, object_name)
        return True
    except ClientError as e:
        logging.error(e)
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
