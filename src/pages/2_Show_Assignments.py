import logging
import streamlit as st
from PIL import Image
from botocore.exceptions import ClientError
import boto3
import os
from components.Parameter_store import S3_BUCKET_NAME, CLOUDFRONT_DOMAIN


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


# Get CloudFront URL for image
def get_image_url(image_name):
    """
    Generate CloudFront URL for the image.
    Falls back to S3 direct URL if CloudFront is not configured.
    """
    if not image_name or image_name == "no image created":
        return None
    
    # Use CloudFront if configured
    if CLOUDFRONT_DOMAIN:
        return f"https://{CLOUDFRONT_DOMAIN}/{image_name}"
    
    # Fallback to S3 direct URL (for development/testing)
    return f"https://{S3_BUCKET_NAME}.s3.amazonaws.com/{image_name}"


# Check if image exists in S3
def check_image_exists(image_name):
    """Check if image exists in S3 bucket"""
    if not image_name or image_name == "no image created":
        return False
    
    s3 = session.client("s3")
    try:
        s3.head_object(Bucket=S3_BUCKET_NAME, Key=image_name)
        return True
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', '')
        if error_code == '404':
            logging.warning(f"Image {image_name} not found in bucket {S3_BUCKET_NAME}")
        else:
            logging.error(f"S3 check error: {e}")
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

    image_name = prompt_selection.get("s3_image_name", "")
    
    # Display image using CloudFront URL
    if image_name and image_name != "no image created":
        image_url = get_image_url(image_name)
        if image_url:
            try:
                st.image(image_url, use_container_width=True)
            except Exception as e:
                logging.error(f"Error displaying image: {e}")
                st.info("📷 Image not available")
        else:
            st.info("📷 No image available for this assignment")
    else:
        st.info("📷 No image available for this assignment")

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
