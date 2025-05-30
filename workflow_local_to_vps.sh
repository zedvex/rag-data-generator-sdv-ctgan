#!/bin/bash

# Laika Dynamics Complete Workflow Script
# Dev Machine -> Local Server -> Generate Data -> Pull Back -> Deploy to VPS

set -e

# Configuration - UPDATE THESE VALUES
LOCAL_SERVER_IP="192.168.1.100"  # Your local Ubuntu server IP
LOCAL_SERVER_USER="username"     # Username on local server
VPS_IP="194.238.17.65"          # Production VPS IP
VPS_USER="user"                  # Username on VPS
SCRIPT_NAME="ubuntu_data_generator.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

echo "🚀 Laika Dynamics Complete Workflow"
echo "===================================="
echo "Flow: Dev Machine -> Local Server -> Generate -> Pull Back -> Deploy to VPS"
echo ""

# Step 1: Deploy to Local Server
deploy_to_local_server() {
    log "Step 1: Deploying to local Ubuntu server..."
    
    # Check if script exists
    if [ ! -f "$SCRIPT_NAME" ]; then
        error "$SCRIPT_NAME not found in current directory"
    fi
    
    # Check local server connectivity
    if ! ping -c 1 "$LOCAL_SERVER_IP" >/dev/null 2>&1; then
        error "Cannot reach local server $LOCAL_SERVER_IP"
    fi
    
    log "✅ Local server is reachable"
    
    # Check server resources
    log "Checking server resources..."
    LOCAL_SERVER_RAM=$(ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" 'free -g | awk "/^Mem:/{print \$2}"' 2>/dev/null || echo "0")
    LOCAL_SERVER_DISK=$(ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" 'df / | awk "NR==2 {print int(\$4/1024/1024)}"' 2>/dev/null || echo "0")
    
    log "Local server RAM: ${LOCAL_SERVER_RAM}GB"
    log "Local server disk: ${LOCAL_SERVER_DISK}GB free"
    
    if [ "$LOCAL_SERVER_RAM" -lt 16 ]; then
        warn "Local server has only ${LOCAL_SERVER_RAM}GB RAM. 18GB+ recommended."
    fi
    
    if [ "$LOCAL_SERVER_DISK" -lt 15 ]; then
        warn "Local server has only ${LOCAL_SERVER_DISK}GB free disk space."
        echo "Run this to clean up:"
        echo "ssh $LOCAL_SERVER_USER@$LOCAL_SERVER_IP 'sudo apt-get clean && sudo apt-get autoremove -y'"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Upload files to local server
    log "Uploading files to local server..."
    scp "$SCRIPT_NAME" "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP:~/"
    scp *.md "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP:~/" 2>/dev/null || true
    
    # Make executable
    ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" "chmod +x $SCRIPT_NAME"
    
    log "✅ Files uploaded to local server"
}

# Step 2: Run Data Generation
run_generation() {
    log "Step 2: Running data generation on local server..."
    
    echo ""
    echo "🔥 Starting CTGAN data generation on $LOCAL_SERVER_IP"
    echo "This will take 30-60 minutes depending on your server specs."
    echo ""
    
    # Option to run in background or foreground
    read -p "Run in background? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Starting generation in background..."
        ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" "nohup ./$SCRIPT_NAME > generation_output.log 2>&1 &"
        log "✅ Generation started in background"
        log "Monitor with: ssh $LOCAL_SERVER_USER@$LOCAL_SERVER_IP 'tail -f generation_output.log'"
        
        # Wait for it to start
        sleep 5
        
        # Check if it's running
        RUNNING=$(ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" "pgrep -f '$SCRIPT_NAME' | wc -l")
        if [ "$RUNNING" -gt 0 ]; then
            log "✅ Generation is running (PID: $(ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" "pgrep -f '$SCRIPT_NAME'"))"
        else
            error "Generation failed to start. Check: ssh $LOCAL_SERVER_USER@$LOCAL_SERVER_IP 'cat generation_output.log'"
        fi
        
    else
        log "Running generation in foreground..."
        ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" "./$SCRIPT_NAME"
        log "✅ Generation completed"
    fi
}

# Step 3: Monitor Generation (if running in background)
monitor_generation() {
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        log "Monitoring options:"
        echo "1. Watch progress: ssh $LOCAL_SERVER_USER@$LOCAL_SERVER_IP 'tail -f generation_output.log'"
        echo "2. Watch resources: ssh $LOCAL_SERVER_USER@$LOCAL_SERVER_IP 'watch \"free -h && df -h /\"'"
        echo "3. Check if running: ssh $LOCAL_SERVER_USER@$LOCAL_SERVER_IP 'pgrep -f $SCRIPT_NAME'"
        echo ""
        
        read -p "Open monitoring session? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" "tail -f generation_output.log"
        fi
    fi
}

# Step 4: Pull Generated Data Back
pull_data_back() {
    log "Step 3: Pulling generated data back to dev machine..."
    
    # Check if generation is complete
    if ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" "[ -f ~/laika-data-generator/laika-dynamics-synthetic-data.tar.gz ]"; then
        log "✅ Generation package found on server"
    else
        error "Generation package not found. Has the generation completed successfully?"
    fi
    
    # Create local directory for the data
    mkdir -p ./generated_data
    
    # Pull back the generated data package
    log "Downloading generated data package..."
    scp "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP:~/laika-data-generator/laika-dynamics-synthetic-data.tar.gz" ./generated_data/
    
    # Pull back logs and summary
    scp "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP:~/laika-data-generator/generation.log" ./generated_data/ 2>/dev/null || true
    scp "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP:~/laika-data-generator/data/synthetic/dataset_summary.json" ./generated_data/ 2>/dev/null || true
    
    log "✅ Data pulled back to ./generated_data/"
    
    # Show what we got
    log "Generated files:"
    ls -la ./generated_data/
}

# Step 5: Deploy to VPS
deploy_to_vps() {
    log "Step 4: Deploying to production VPS..."
    
    # Check if we have the data package
    if [ ! -f "./generated_data/laika-dynamics-synthetic-data.tar.gz" ]; then
        error "Generated data package not found in ./generated_data/"
    fi
    
    # Check VPS connectivity
    if ! ping -c 1 "$VPS_IP" >/dev/null 2>&1; then
        error "Cannot reach VPS $VPS_IP"
    fi
    
    log "✅ VPS is reachable"
    
    # Upload data package to VPS
    log "Uploading data package to VPS..."
    scp ./generated_data/laika-dynamics-synthetic-data.tar.gz "$VPS_USER@$VPS_IP:~/"
    
    # Upload summary and logs for reference
    scp ./generated_data/dataset_summary.json "$VPS_USER@$VPS_IP:~/" 2>/dev/null || true
    scp ./generated_data/generation.log "$VPS_USER@$VPS_IP:~/" 2>/dev/null || true
    
    log "✅ Files uploaded to VPS"
    
    # Extract and organize on VPS
    log "Extracting and organizing data on VPS..."
    ssh "$VPS_USER@$VPS_IP" << 'EOF'
cd ~/
tar -xzf laika-dynamics-synthetic-data.tar.gz
mkdir -p ~/laika-dynamics-rag/data/
mv data/synthetic ~/laika-dynamics-rag/data/ 2>/dev/null || true
rm -f laika-dynamics-synthetic-data.tar.gz
EOF
    
    log "✅ Data extracted and organized on VPS"
}

# Step 6: Cleanup Local Server
cleanup_local_server() {
    log "Step 5: Cleaning up local server..."
    
    read -p "Clean up local server files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ssh "$LOCAL_SERVER_USER@$LOCAL_SERVER_IP" << 'EOF'
rm -rf ~/laika-data-generator
rm -f ~/ubuntu_data_generator.sh
rm -f ~/README_18GB_OPTIMIZATION.md
rm -f ~/DISK_SPACE_TROUBLESHOOTING.md
rm -f ~/generation_output.log
EOF
        log "✅ Local server cleaned up"
    else
        log "ℹ️  Local server files kept for reference"
    fi
}

# Main workflow
main() {
    echo "Configuration:"
    echo "  Local Server: $LOCAL_SERVER_USER@$LOCAL_SERVER_IP"
    echo "  VPS: $VPS_USER@$VPS_IP"
    echo ""
    
    read -p "Proceed with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Edit the configuration at the top of this script and try again."
        exit 1
    fi
    
    # Run the workflow
    deploy_to_local_server
    run_generation
    monitor_generation
    
    echo ""
    log "⏳ Waiting for generation to complete..."
    echo "   Run this script again with --pull-only to continue once generation is done."
    echo ""
    
    # If generation was run in foreground, continue immediately
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        pull_data_back
        deploy_to_vps
        cleanup_local_server
        
        echo ""
        echo "🎉 Complete workflow finished!"
        echo "==============================================="
        echo "✅ Data generated on local server"
        echo "✅ Data pulled back to dev machine"  
        echo "✅ Data deployed to VPS"
        echo "✅ Ready for RAG system integration"
        echo ""
        echo "Next steps on VPS:"
        echo "1. SSH to VPS: ssh $VPS_USER@$VPS_IP"
        echo "2. Verify data: ls -la ~/laika-dynamics-rag/data/synthetic/"
        echo "3. Restart RAG services to load new data"
    fi
}

# Handle command line arguments
if [ "$1" == "--pull-only" ]; then
    log "Running pull-only mode..."
    pull_data_back
    deploy_to_vps
    cleanup_local_server
    echo "🎉 Pull and deploy completed!"
elif [ "$1" == "--help" ]; then
    echo "Usage:"
    echo "  $0           - Run complete workflow"
    echo "  $0 --pull-only - Only pull data and deploy (after generation is done)"
    echo "  $0 --help    - Show this help"
else
    main
fi 