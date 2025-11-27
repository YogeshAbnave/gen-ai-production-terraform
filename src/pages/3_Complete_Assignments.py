import json
import logging
import requests
import streamlit as st
import numpy as np
from PIL import Image
from botocore.exceptions import ClientError
import boto3
from scipy.spatial import distance
import os
from components.Parameter_store import S3_BUCKET_NAME

answer = None
show_prompt = None
prompt = None

# AWS + DynamoDB setup
aws_region = os.getenv("AWS_REGION", "us-east-1")
dynamodb_table_name = os.getenv("DYNAMODB_TABLE_NAME", "app-data-table")

session = boto3.Session(
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=aws_region,
)

bedrock_client = session.client("bedrock-runtime")
dynamodb_resource = session.resource("dynamodb")
assignments_table = dynamodb_resource.Table(dynamodb_table_name)
user_name = "CloudAge-User"


# ---------------- Functions ---------------- #
def get_assignments_from_dynamodb():
    """Retrieve assignments from DynamoDB."""
    try:
        response = assignments_table.scan(
            FilterExpression="attribute_exists(record_type) AND record_type = :type",
            ExpressionAttributeValues={":type": "assignment"}
        )
        records = response.get("Items", [])
        
        # Handle pagination
        while "LastEvaluatedKey" in response:
            response = assignments_table.scan(
                FilterExpression="attribute_exists(record_type) AND record_type = :type",
                ExpressionAttributeValues={":type": "assignment"},
                ExclusiveStartKey=response["LastEvaluatedKey"]
            )
            records.extend(response.get("Items", []))
        
        return records
    except ClientError as e:
        st.error(f"Error fetching assignments: {str(e)}")
        return []


def download_image(image_name, file_name):
    """Download images from S3 bucket."""
    s3 = session.client("s3")
    try:
        # Check if bucket exists
        s3.head_bucket(Bucket=S3_BUCKET_NAME)
        s3.download_file(S3_BUCKET_NAME, image_name, file_name)
        return True
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', '')
        if error_code == '404':
            logging.warning(f"Bucket {S3_BUCKET_NAME} or object {image_name} not found")
        else:
            logging.error(f"S3 download error: {e}")
        return False


def get_answer_record_from_dynamodb(student_id, assignment_id, question_id):
    """Get student's answer for a specific assignment + question."""
    try:
        answer_id = f"answer_{student_id}_{assignment_id}_{question_id}"
        response = assignments_table.get_item(Key={"id": answer_id})
        return response.get("Item")
    except ClientError as e:
        logging.error(f"Error getting answer: {str(e)}")
        return None


def save_answer_record(student_id, assignment_id, question_id, answer, score):
    """Insert or update student's answer with highest score only."""
    try:
        answer_id = f"answer_{student_id}_{assignment_id}_{question_id}"
        
        # Get existing record to check score
        existing = get_answer_record_from_dynamodb(student_id, assignment_id, question_id)
        
        # Only update if new score is higher or no existing record
        if not existing or float(score) > float(existing.get("score", 0)):
            assignments_table.put_item(
                Item={
                    "id": answer_id,
                    "student_id": student_id,
                    "assignment_id": assignment_id,
                    "question_id": str(question_id),
                    "assignment_question_id": f"{assignment_id}_{question_id}",
                    "answer": answer,
                    "score": str(score),
                    "record_type": "answer"
                }
            )
    except ClientError as e:
        logging.error(f"Error saving answer: {str(e)}")
        raise


def get_high_score_answer_records_from_dynamodb(assignment_id, question_id, limit=5):
    """Get top scores for a specific question."""
    try:
        response = assignments_table.scan(
            FilterExpression="record_type = :type AND assignment_question_id = :aq_id",
            ExpressionAttributeValues={
                ":type": "answer",
                ":aq_id": f"{assignment_id}_{question_id}"
            }
        )
        
        records = response.get("Items", [])
        
        # Sort by score descending and limit
        sorted_records = sorted(records, key=lambda x: float(x.get("score", 0)), reverse=True)
        return sorted_records[:limit]
    except ClientError as e:
        logging.error(f"Error getting high scores: {str(e)}")
        return []


def get_text_embed(payload):
    """Call Bedrock Titan embeddings."""
    input_body = {"inputText": payload}
    api_response = bedrock_client.invoke_model(
        body=json.dumps(input_body),
        modelId="amazon.titan-embed-text-v2:0",
        accept="application/json",
        contentType="application/json",
    )
    embedding_response = json.loads(api_response.get("body").read().decode("utf-8"))
    return list(embedding_response["embedding"])


def generate_suggestions_sentence_improvements(text):
    model_id = "mistral.mistral-7b-instruct-v0:2"
    input_text = f"""{text}\nImprove the text above in a way that maintains its original meaning but uses different words and sentence structures. Keep your response in 1 sentence."""
    body = json.dumps(
        {
            "prompt": input_text,
            "max_tokens": 400,
            "temperature": 0,
            "top_p": 0.7,
            "top_k": 50,
        }
    )

    response = bedrock_client.invoke_model(body=body, modelId=model_id)
    response_body = json.loads(response.get("body").read())
    return "\n".join([output["text"] for output in response_body.get("outputs", [])])


def generate_suggestions_word_improvements(text):
    model_id = "mistral.mistral-7b-instruct-v0:2"
    input_text = f"""{text}\nReview the text above and correct any grammar errors. Keep your response in 1 sentence."""
    body = json.dumps(
        {
            "prompt": input_text,
            "max_tokens": 400,
            "temperature": 0,
            "top_p": 0.7,
            "top_k": 50,
        }
    )

    response = bedrock_client.invoke_model(body=body, modelId=model_id)
    response_body = json.loads(response.get("body").read())
    return "\n".join([output["text"] for output in response_body.get("outputs", [])])


# ---------------- Streamlit UI ---------------- #
st.set_page_config(page_title="Answer Questions", page_icon=":question:", layout="wide")

st.markdown("# Answer Questions")
st.sidebar.header("Answer Questions")

# Load assignments from DynamoDB
assignment_records = get_assignments_from_dynamodb()
assignment_ids = [record["assignment_id"] for record in assignment_records]
assignment_ids.insert(0, "<Select>")

assignment_id_selection = st.sidebar.selectbox("Select an assignment", assignment_ids)
assignment_selection = None

if assignment_id_selection and assignment_id_selection != "<Select>":
    for assignment_record in assignment_records:
        if assignment_record["assignment_id"] == assignment_id_selection:
            assignment_selection = assignment_record

if assignment_selection:
    # Show image
    image_name = assignment_selection["s3_image_name"]
    file_name = "temp-answer.png"
    if download_image(image_name, file_name):
        st.image(Image.open(file_name), width=128)

    # Show prompt
    st.write(assignment_selection["prompt"])

    # Select question
    question_answers = json.loads(assignment_selection["question_answers"])
    questions = [qa["Question"] for qa in question_answers]
    generate_question_selection = st.selectbox("Select a question", questions)

    answer = st.text_input("Please enter your answer!", key="prompt")

    # Match correct answer
    correct_answer, question_id = None, None
    for qa in question_answers:
        if qa["Question"] == generate_question_selection:
            correct_answer, question_id = qa["Answer"], qa["Id"]
            break

    if answer and correct_answer:
        st.write("Your guess:", answer)

        v1 = np.squeeze(np.array(get_text_embed(correct_answer)))
        v2 = np.squeeze(np.array(get_text_embed(answer)))
        dist = distance.cosine(v1, v2)
        score = int(100 - dist * 100)
        st.write(f"Your answer has a score of {score}")

        st.markdown("------------")

        # Save/update best score in DynamoDB
        save_answer_record(
            user_name, assignment_id_selection, question_id, answer, score
        )
        st.write(
            f"Your highest score has been updated. Score: {score}, Answer: '{answer}'"
        )

        # Show leaderboard
        high_score_records = get_high_score_answer_records_from_dynamodb(
            assignment_id_selection, question_id
        )
        st.write("Top Three High Scores:")
        for record in high_score_records:
            st.write(f"Student ID: {record['student_id']} - Score: {record['score']}")

        # Suggestions
        st.markdown("------------")
        st.markdown("Suggested corrections:")
        st.write(generate_suggestions_word_improvements(answer))

        st.markdown("Suggested sentences:")
        st.write(generate_suggestions_sentence_improvements(answer))

        if st.button("Show the correct answer"):
            st.write("Answer:")
            st.write(correct_answer)


# Hide Streamlit UI branding
hide_streamlit_style = """
    <style>
        #MainMenu {visibility: hidden;}
        footer {visibility: hidden;}
    </style>
"""
st.markdown(hide_streamlit_style, unsafe_allow_html=True)
