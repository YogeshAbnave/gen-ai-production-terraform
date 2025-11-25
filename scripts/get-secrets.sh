#!/bin/bash
# Automatically extract GitHub Secrets from Terraform

set -e

echo "🔐 Extracting GitHub Secrets from Terraform"
echo "============================================"
echo ""

# Check if infrastructure directory exists
if [ ! -d "infrastructure" ]; then
    echo "❌ Error: infrastructure directory not found"
    exit 1
fi

cd infrastructure

# Check if Terraform has been applied
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ Error: Terraform state not found"
    echo "Please run 'terraform apply' first"
    exit 1
fi

echo "📋 Extracting values from Terraform..."
echo ""

# Get EC2 IP
EC2_HOST=$(terraform output -raw ec2_public_ip 2>/dev/null || echo "")

# Get private key path
PRIVATE_KEY_PATH=$(terraform output -raw private_key_path 2>/dev/null || echo "")

if [ -z "$EC2_HOST" ]; then
    echo "❌ Error: Could not get EC2 IP from Terraform"
    exit 1
fi

if [ -z "$PRIVATE_KEY_PATH" ] || [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo "❌ Error: Private key not found"
    exit 1
fi

cd ..

echo "✅ Successfully extracted all secrets!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 GitHub Secrets Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Go to: https://github.com/YogeshAbnave/terraform-crud/settings/secrets/actions"
echo ""
echo "Add these 2 secrets:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  EC2_HOST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$EC2_HOST"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  EC2_PRIVATE_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat "$PRIVATE_KEY_PATH"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Instructions:"
echo "   1. Copy EC2_HOST value above"
echo "   2. Copy EC2_PRIVATE_KEY value above (including BEGIN/END lines)"
echo "   3. Add both to GitHub Secrets"
echo ""
echo "🔗 Quick Links:"
echo "   • GitHub Secrets: https://github.com/YogeshAbnave/terraform-crud/settings/secrets/actions"
echo "   • GitHub Actions: https://github.com/YogeshAbnave/terraform-crud/actions"
echo "   • Application URL: http://$EC2_HOST"
echo "   • API URL: http://$EC2_HOST/api"
echo "   • SSH Command: ssh -i $PRIVATE_KEY_PATH ubuntu@$EC2_HOST"
echo ""
echo "✅ After adding secrets, push to main branch to trigger deployment!"
echo ""
