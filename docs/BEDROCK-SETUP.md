# Amazon Bedrock Model Setup Guide

## Overview

This application uses Amazon Bedrock for AI-powered features. By default, it uses Amazon Titan models which are available without additional subscriptions.

## Current Configuration

- **Text Model**: `amazon.titan-text-express-v1` (Default)
- **Image Model**: `amazon.titan-image-generator-v1` (Default)

## Enabling Bedrock Model Access

### Step 1: Enable Model Access in AWS Console

1. Go to the [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock/)
2. Select your region (ap-south-1 - Mumbai)
3. Click on "Model access" in the left navigation
4. Click "Manage model access" or "Enable specific models"
5. Select the models you want to use:
   - **Amazon Titan Text Express** (Recommended - No subscription needed)
   - **Amazon Titan Image Generator** (Recommended - No subscription needed)
   - **Anthropic Claude 3** (Requires AWS Marketplace subscription)
   - **Amazon Nova** (May require additional permissions)

6. Click "Save changes"
7. Wait for the status to change to "Access granted" (usually takes a few minutes)

### Step 2: Verify Model Availability

Check which models are available in your region:

```bash
aws bedrock list-foundation-models --region ap-south-1 --query "modelSummaries[].{ModelId:modelId, Name:modelName, Status:modelLifecycle.status}" --output table
```

### Step 3: Update Model Configuration (Optional)

If you want to use different models, update the environment variables in the deployment:

**For GitHub Actions deployment**, update `.github/workflows/deploy.yml`:

```yaml
Environment=BEDROCK_TEXT_MODEL_ID=your-preferred-text-model
Environment=BEDROCK_IMAGE_MODEL_ID=your-preferred-image-model
```

**For manual deployment**, update the systemd service file on EC2:

```bash
sudo nano /etc/systemd/system/streamlit.service
```

Add or update:
```
Environment=BEDROCK_TEXT_MODEL_ID=your-preferred-text-model
Environment=BEDROCK_IMAGE_MODEL_ID=your-preferred-image-model
```

Then restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart streamlit
```

## Available Model IDs

### Text Generation Models

| Model ID | Name | Subscription Required |
|----------|------|----------------------|
| `amazon.titan-text-express-v1` | Titan Text Express | No |
| `amazon.titan-text-lite-v1` | Titan Text Lite | No |
| `anthropic.claude-3-sonnet-20240229-v1:0` | Claude 3 Sonnet | Yes (Marketplace) |
| `anthropic.claude-3-haiku-20240307-v1:0` | Claude 3 Haiku | Yes (Marketplace) |
| `amazon.nova-pro-v1:0` | Nova Pro | May vary by region |
| `amazon.nova-lite-v1:0` | Nova Lite | May vary by region |

### Image Generation Models

| Model ID | Name | Subscription Required |
|----------|------|----------------------|
| `amazon.titan-image-generator-v1` | Titan Image Generator | No |
| `amazon.nova-canvas-v1:0` | Nova Canvas | May vary by region |
| `stability.stable-diffusion-xl-v1` | Stable Diffusion XL | Yes (Marketplace) |

## Troubleshooting

### Error: "Model access is denied"

This error occurs when:
1. The model hasn't been enabled in the Bedrock console
2. The IAM role lacks necessary permissions
3. The model requires AWS Marketplace subscription

**Solution:**
1. Enable the model in Bedrock console (see Step 1 above)
2. Wait 10 minutes for changes to propagate
3. For marketplace models, subscribe in AWS Marketplace first

### Error: "The provided model identifier is invalid"

This error occurs when:
1. The model ID is incorrect
2. The model is not available in your region
3. The model has been deprecated

**Solution:**
1. Verify the model ID using `aws bedrock list-foundation-models`
2. Check if the model is available in ap-south-1 region
3. Use a different model from the available list

### Error: "You must specify a region"

This error occurs when the AWS region is not configured.

**Solution:**
1. Ensure `AWS_REGION` environment variable is set in the systemd service
2. Verify the deployment workflow includes the region configuration
3. Check that the boto3 session is created with the region parameter

## IAM Permissions Required

The EC2 instance role needs these Bedrock permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ListFoundationModels",
        "bedrock:GetFoundationModel"
      ],
      "Resource": "*"
    }
  ]
}
```

For Claude models, additional marketplace permissions may be needed:
```json
{
  "Effect": "Allow",
  "Action": [
    "aws-marketplace:ViewSubscriptions",
    "aws-marketplace:Subscribe"
  ],
  "Resource": "*"
}
```

## Testing Model Access

Test if a model is accessible:

```python
import boto3
import json

bedrock = boto3.client('bedrock-runtime', region_name='ap-south-1')

# Test Titan Text
response = bedrock.invoke_model(
    modelId='amazon.titan-text-express-v1',
    body=json.dumps({
        "inputText": "Hello, world!",
        "textGenerationConfig": {
            "maxTokenCount": 100,
            "temperature": 0.7
        }
    })
)

print(json.loads(response['body'].read()))
```

## Support

For more information:
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Bedrock Model Access](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
