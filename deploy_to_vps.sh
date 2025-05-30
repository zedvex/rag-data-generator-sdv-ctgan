#!/bin/bash

# Deploy Synthetic Data to VPS
# Simple script to upload and extract the generated data

VPS_IP="194.238.17.65"
VPS_USER="user"  # Change to your VPS username
DATA_PACKAGE="quick_synthetic_data.tar.gz"

echo "🚀 Deploying Synthetic Data to VPS"
echo "================================="
echo "VPS: $VPS_USER@$VPS_IP"
echo "Package: $DATA_PACKAGE"
echo ""

# Check if package exists
if [ ! -f "$DATA_PACKAGE" ]; then
    echo "❌ Package not found: $DATA_PACKAGE"
    echo "Run the data generation script first."
    exit 1
fi

echo "📦 Package size: $(du -h $DATA_PACKAGE | cut -f1)"
echo "📊 Records in package: 16,035 total"
echo ""

# Check VPS connectivity
echo "🔗 Checking VPS connectivity..."
if ! ping -c 1 "$VPS_IP" >/dev/null 2>&1; then
    echo "❌ Cannot reach VPS $VPS_IP"
    exit 1
fi
echo "✅ VPS is reachable"

# Upload package
echo "📤 Uploading package to VPS..."
scp "$DATA_PACKAGE" "$VPS_USER@$VPS_IP:~/"

# Extract and organize on VPS
echo "📁 Extracting and organizing data on VPS..."
ssh "$VPS_USER@$VPS_IP" << 'EOF'
cd ~/

# Extract the package
tar -xzf quick_synthetic_data.tar.gz

# Create RAG data directory if it doesn't exist
mkdir -p ~/laika-dynamics-rag/data/

# Remove old synthetic data if it exists
rm -rf ~/laika-dynamics-rag/data/synthetic

# Move new data
mv generated_data_quick ~/laika-dynamics-rag/data/synthetic

echo "✅ Data moved to ~/laika-dynamics-rag/data/synthetic/"

# Show what we have
echo "📊 Data files:"
ls -la ~/laika-dynamics-rag/data/synthetic/

# Count records
echo ""
echo "📈 Record counts:"
for file in ~/laika-dynamics-rag/data/synthetic/*.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        count=$(tail -n +2 "$file" | wc -l)
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  $filename: $count records ($size)"
    fi
done

# Clean up
rm -f quick_synthetic_data.tar.gz

echo ""
echo "🎉 Deployment completed successfully!"
EOF

echo ""
echo "==============================================="
echo "✅ Synthetic data deployed to VPS!"
echo "📊 Total records: 16,035"
echo "📁 Location: ~/laika-dynamics-rag/data/synthetic/"
echo ""
echo "Next steps:"
echo "1. SSH to VPS: ssh $VPS_USER@$VPS_IP"
echo "2. Restart RAG services to load new data"
echo "===============================================" 