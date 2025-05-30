#!/bin/bash

# Laika Dynamics Server Deployment Script
# Deploys the CTGAN data generator to VPS: 194.238.17.65

set -e

VPS_IP="194.238.17.65"
VPS_USER="user"  # Change this to your actual username
SCRIPT_NAME="ubuntu_data_generator.sh"

echo "🚀 Laika Dynamics Server Deployment"
echo "=================================="

# Check if script exists locally
if [ ! -f "$SCRIPT_NAME" ]; then
    echo "❌ Error: $SCRIPT_NAME not found in current directory"
    exit 1
fi

echo "📋 Pre-deployment server check..."

# Check server connectivity
if ! ping -c 1 "$VPS_IP" >/dev/null 2>&1; then
    echo "❌ Error: Cannot reach server $VPS_IP"
    exit 1
fi

echo "✅ Server is reachable"

# Check server disk space
echo "📊 Checking server disk space..."
SERVER_DISK_SPACE=$(ssh "$VPS_USER@$VPS_IP" 'df / | awk "NR==2 {print int(\$4/1024/1024)}"' 2>/dev/null || echo "0")

if [ "$SERVER_DISK_SPACE" -lt 10 ]; then
    echo "⚠️  Warning: Server has only ${SERVER_DISK_SPACE}GB free space"
    echo "   Minimum required: 10GB"
    echo "   Recommended: 15GB+"
    echo ""
    echo "Run this on server to free up space:"
    echo "   ssh $VPS_USER@$VPS_IP 'sudo apt-get clean && sudo apt-get autoremove -y'"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Server disk space: ${SERVER_DISK_SPACE}GB available"
fi

# Transfer files to server
echo "📤 Uploading files to server..."

# Upload main script
scp "$SCRIPT_NAME" "$VPS_USER@$VPS_IP:~/"
echo "✅ Uploaded $SCRIPT_NAME"

# Upload documentation
if [ -f "README_18GB_OPTIMIZATION.md" ]; then
    scp "README_18GB_OPTIMIZATION.md" "$VPS_USER@$VPS_IP:~/"
    echo "✅ Uploaded README_18GB_OPTIMIZATION.md"
fi

if [ -f "DISK_SPACE_TROUBLESHOOTING.md" ]; then
    scp "DISK_SPACE_TROUBLESHOOTING.md" "$VPS_USER@$VPS_IP:~/"
    echo "✅ Uploaded DISK_SPACE_TROUBLESHOOTING.md"
fi

# Make script executable on server
ssh "$VPS_USER@$VPS_IP" "chmod +x $SCRIPT_NAME"
echo "✅ Made script executable on server"

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "1. SSH to your server:"
echo "   ssh $VPS_USER@$VPS_IP"
echo ""
echo "2. Run the data generator:"
echo "   ./$SCRIPT_NAME"
echo ""
echo "3. Monitor progress (in another terminal):"
echo "   ssh $VPS_USER@$VPS_IP 'tail -f ~/laika-data-generator/generation.log'"
echo ""
echo "4. If you encounter disk space issues, refer to:"
echo "   cat ~/DISK_SPACE_TROUBLESHOOTING.md"
echo ""
echo "🔧 Advanced monitoring commands:"
echo "   # Watch disk space during generation"
echo "   ssh $VPS_USER@$VPS_IP 'watch df -h /'"
echo ""
echo "   # Monitor memory usage"
echo "   ssh $VPS_USER@$VPS_IP 'watch free -h'"
echo ""
echo "   # Check system resources"
echo "   ssh $VPS_USER@$VPS_IP 'htop'"

# Optional: Offer to SSH directly
echo ""
read -p "🔗 SSH to server now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Connecting to server..."
    ssh "$VPS_USER@$VPS_IP"
fi 