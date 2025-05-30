#!/bin/bash

# Simple script to deploy already-generated data to VPS
# Use this if you already have the data package locally

set -e

VPS_IP="194.238.17.65"
VPS_USER="user"  # Change to your VPS username
DATA_PACKAGE="./generated_data/laika-dynamics-synthetic-data.tar.gz"

echo "🚀 Deploying Generated Data to VPS"
echo "================================="

# Check if data package exists
if [ ! -f "$DATA_PACKAGE" ]; then
    echo "❌ Data package not found: $DATA_PACKAGE"
    echo ""
    echo "Expected file locations:"
    echo "  ./generated_data/laika-dynamics-synthetic-data.tar.gz"
    echo "  OR"
    echo "  ./laika-dynamics-synthetic-data.tar.gz"
    echo ""
    
    # Check alternative location
    if [ -f "./laika-dynamics-synthetic-data.tar.gz" ]; then
        DATA_PACKAGE="./laika-dynamics-synthetic-data.tar.gz"
        echo "✅ Found data package: $DATA_PACKAGE"
    else
        exit 1
    fi
else
    echo "✅ Found data package: $DATA_PACKAGE"
fi

# Check VPS connectivity
echo "🔗 Checking VPS connectivity..."
if ! ping -c 1 "$VPS_IP" >/dev/null 2>&1; then
    echo "❌ Cannot reach VPS $VPS_IP"
    exit 1
fi
echo "✅ VPS is reachable"

# Upload data package
echo "📤 Uploading data package to VPS..."
scp "$DATA_PACKAGE" "$VPS_USER@$VPS_IP:~/"

# Upload additional files if they exist
if [ -f "./generated_data/dataset_summary.json" ]; then
    scp "./generated_data/dataset_summary.json" "$VPS_USER@$VPS_IP:~/"
fi

if [ -f "./generated_data/generation.log" ]; then
    scp "./generated_data/generation.log" "$VPS_USER@$VPS_IP:~/"
fi

echo "✅ Files uploaded to VPS"

# Extract and organize on VPS
echo "📁 Extracting and organizing data on VPS..."
ssh "$VPS_USER@$VPS_IP" << 'EOF'
cd ~/

# Extract the package
tar -xzf laika-dynamics-synthetic-data.tar.gz

# Create RAG data directory if it doesn't exist
mkdir -p ~/laika-dynamics-rag/data/

# Move synthetic data to RAG directory
if [ -d "data/synthetic" ]; then
    # Remove old synthetic data if it exists
    rm -rf ~/laika-dynamics-rag/data/synthetic
    
    # Move new data
    mv data/synthetic ~/laika-dynamics-rag/data/
    
    echo "✅ Synthetic data moved to ~/laika-dynamics-rag/data/synthetic/"
else
    echo "❌ No synthetic data directory found in package"
    exit 1
fi

# Clean up
rm -f laika-dynamics-synthetic-data.tar.gz
rm -rf data

# Show what we have
echo "📊 Data files in RAG directory:"
ls -la ~/laika-dynamics-rag/data/synthetic/

# Count records in each file
echo ""
echo "📈 Record counts:"
for file in ~/laika-dynamics-rag/data/synthetic/*.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        count=$(tail -n +2 "$file" | wc -l)
        echo "  $filename: $count records"
    fi
done
EOF

echo ""
echo "🎉 Deployment completed successfully!"
echo "================================="
echo "✅ Data extracted and organized on VPS"
echo "✅ Ready for RAG system integration"
echo ""
echo "Next steps:"
echo "1. SSH to VPS: ssh $VPS_USER@$VPS_IP"
echo "2. Verify data: ls -la ~/laika-dynamics-rag/data/synthetic/"
echo "3. Restart your RAG services to load the new data"
echo ""
echo "RAG integration commands:"
echo "  # If using Docker Compose"
echo "  ssh $VPS_USER@$VPS_IP 'cd ~/laika-dynamics-rag && docker-compose restart'"
echo ""
echo "  # If using systemd service"
echo "  ssh $VPS_USER@$VPS_IP 'sudo systemctl restart laika-rag-service'" 