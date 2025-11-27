import logging
import streamlit as st
from PIL import Image
from botocore.exceptions import ClientError
import boto3
import os
from components.Parameter_store import S3_BUCKET_NAME


# ---------------- AWS + DynamoDB Setup ---------------- #
aws_region = os.getenv("AWS_REGION", "us-east-1")
dynamodb_table_name = os.getenv("DYNAMODB_TABLE_NAME", "app-data-table")

session = boto3.Session(
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=aws_region,
)

dynamodb_resource = session.resource("dynamodb")
assignments_table = dynamodb_resource.Table(dynamodb_table_name)


# ---------------- Functions ---------------- #
# Fetch records from DynamoDB
def get_records_from_dynamodb():
    try:
        response = assignments_table.scan(
            FilterExpression="attribute_exists(record_type) AND record_type = :type",
            ExpressionAttributeValues={":type": "assignment"}
        )
        records = response.get("Items", [])
        
        # Handle pagination if there are more items
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


# Download image from S3 bucket
def download_image(image_name, file_name):
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


# ---------------- Streamlit UI ---------------- #
st.set_page_config(page_title="Show Assignment", page_icon=":bar_chart:", layout="wide")

st.markdown("# Selected Assignment")
st.sidebar.header("Show Assignments")

# Get assignments from DynamoDB
db_records = get_records_from_dynamodb()
prompts = [record["assignment_id"] for record in db_records]

prompt_option = st.sidebar.selectbox("Select an assignment", prompts)

if prompt_option:
    for record in db_records:
        if record["assignment_id"] == prompt_option:
            prompt_selection = record

    image_name = prompt_selection["s3_image_name"]
    file_name = "temp-show.png"
    if (
        image_name
        and image_name != "no image created"
        and download_image(image_name, file_name)
    ):
        st.image(Image.open(file_name), width=128)
    else:
        st.write("Image not found")

    st.write(prompt_selection["prompt"])
    st.text_area("", prompt_selection["question_answers"], height=320)

# Hide Streamlit branding
hide_streamlit_style = """
    <style>
        #MainMenu {visibility: hidden;}
        footer{visibility: hidden;}
    </style>
"""
st.markdown(hide_streamlit_style, unsafe_allow_html=True)
