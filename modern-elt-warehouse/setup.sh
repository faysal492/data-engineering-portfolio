#!/bin/bash
# Setup script for Modern ELT Warehouse project
# This script guides you through the entire setup process

set -e

echo "🚀 Modern ELT Warehouse - Complete Setup"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check Python version
echo "✅ Step 1: Checking Python environment..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "   Python version: $PYTHON_VERSION"

# 2. Check virtual environment
if [ -d "venv" ]; then
    echo "✅ Virtual environment found"
    source venv/bin/activate
else
    echo "❌ Virtual environment not found. Run: python3 -m venv venv"
    exit 1
fi

# 3. Check dependencies
echo ""
echo "✅ Step 2: Checking dependencies..."
python3 -c "import dbt.version; import google.cloud; import kaggle; print('   All dependencies installed')" || {
    echo "❌ Missing dependencies. Run: pip install -r requirements.txt"
    exit 1
}

# 4. Check GCP setup
echo ""
echo "✅ Step 3: Checking GCP configuration..."
if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
    echo "   GCP credentials configured"
else
    echo "⚠️  GCP credentials not configured"
    echo "   Run: gcloud auth application-default login"
fi

# 5. Check Kaggle setup
echo ""
echo "✅ Step 4: Checking Kaggle setup..."
if [ -f "$HOME/.kaggle/kaggle.json" ]; then
    echo "   Kaggle credentials found"
    KAGGLE_READY=true
else
    echo "❌ Kaggle credentials not found"
    echo ""
    echo "   To download the dataset:"
    echo "   1. Go to: https://kaggle.com/settings/account"
    echo "   2. Click 'Create New Token'"
    echo "   3. Save the downloaded kaggle.json to ~/.kaggle/"
    echo "   4. Run: chmod 600 ~/.kaggle/kaggle.json"
    echo ""
    KAGGLE_READY=false
fi

# 6. Check Terraform
echo ""
echo "✅ Step 5: Checking Terraform..."
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version 2>&1 | head -1)
    echo "   $TERRAFORM_VERSION"
else
    echo "⚠️  Terraform not found. Install from: https://www.terraform.io/downloads"
fi

# 7. Show infrastructure status
echo ""
echo "✅ Step 6: GCP Infrastructure Status"
if [ -f "terraform/terraform.tfstate" ]; then
    echo "   Infrastructure deployed ✅"
    echo ""
    echo "   Resources:"
    echo "   - GCS Buckets: modern-elt-warehouse-{raw,processed}-zone"
    echo "   - BigQuery Datasets: olist_{bronze,silver,gold,dev}"
    echo "   - Service Account: elt-pipeline@modern-elt-warehouse.iam.gserviceaccount.com"
else
    echo "   Infrastructure not deployed"
    echo "   Run: cd terraform && terraform apply -auto-approve"
fi

# 8. Provide next steps
echo ""
echo "========================================="
echo "📋 Next Steps:"
echo "========================================="

if [ "$KAGGLE_READY" = true ]; then
    echo ""
    echo "1️⃣  Download Kaggle dataset:"
    echo "   python scripts/data_acquisition.py"
    echo ""
    echo "2️⃣  Upload to GCS:"
    echo "   python scripts/gcs_loader.py --bucket modern-elt-warehouse-raw-zone"
    echo ""
    echo "3️⃣  Profile data quality:"
    echo "   python scripts/data_profiler.py"
    echo ""
    echo "4️⃣  Run dbt models:"
    echo "   cd dbt_project && dbt run"
else
    echo ""
    echo "1️⃣  Set up Kaggle credentials (see instructions above)"
    echo "2️⃣  Then run: python scripts/data_acquisition.py"
fi

echo ""
echo "📖 Documentation:"
echo "   - README.md - Project overview"
echo "   - QUICKSTART.md - Deployment guide"
echo "   - GCP_SETUP.md - GCP configuration"
echo "   - KAGGLE_SETUP.md - Dataset download guide"
echo "   - docs/data_dictionary.md - Data schema"
echo ""
