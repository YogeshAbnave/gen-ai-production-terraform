import os

import streamlit as st

S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "education-portal-images-a6833f4f")
CLOUDFRONT_DOMAIN = os.getenv("CLOUDFRONT_DOMAIN", "")
