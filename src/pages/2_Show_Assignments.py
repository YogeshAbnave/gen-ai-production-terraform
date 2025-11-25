import logging
import streamlit as st
from PIL import Image
from botocore.exceptions import ClientError
import boto3
from pymongo import MongoClient
import os
from components.Parameter_store import S3_BUCKET_NAME


# ---------------- AWS + MongoDB Setup ---------------- #
aws_region = os.getenv("AWS_REGION", "us-east-1")
mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017/")

session = boto3.Session(
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=aws_region,
)

client = MongoClient(mongo_uri)

# Database & Collection
db = client["assignments_db"]
assignments_collection = db["assignments"]


# ---------------- Functions ---------------- #
# Fetch records from MongoDB
def get_records_from_mongodb():
    records = list(assignments_collection.find({}, {"_id": 0}))  # exclude internal _id
    return records


# Download image from S3 bucket
def download_image(image_name, file_name):
    s3 = session.client("s3")
    try:
        s3.download_file(S3_BUCKET_NAME, image_name, file_name)
        return True
    except ClientError as e:
        logging.error(e)
        return False


# ---------------- Streamlit UI ---------------- #
st.set_page_config(page_title="Show Assignment", page_icon=":bar_chart:", layout="wide")

st.markdown("# Selected Assignment")
st.sidebar.header("Show Assignments")

# Get assignments from MongoDB
db_records = get_records_from_mongodb()
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
