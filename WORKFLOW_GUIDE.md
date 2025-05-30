# Laika Dynamics Data Generation Workflow Guide

## Overview

This guide covers the complete workflow for generating synthetic data on your local Ubuntu server and deploying it to your VPS for RAG system integration.

## Workflow: Dev Machine → Local Server → Generate → Pull Back → Deploy to VPS

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Dev Machine   │───▶│  Local Server   │───▶│   VPS Server    │
│  (Your Laptop)  │    │ (Data Generate) │    │  (RAG System)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        ▲                        │                        ▲
        │                        ▼                        │
        └────────── Pull Generated Data ──────────────────┘
```

## Files in This Package

| File | Purpose |
|------|---------|
| `ubuntu_data_generator.sh` | Main CTGAN data generator (18GB RAM optimized) |
| `workflow_local_to_vps.sh` | Complete automated workflow script |
| `deploy_generated_data_to_vps.sh` | Simple script to deploy existing data to VPS |
| `deploy_to_server.sh` | Direct deployment to any server |
| `README_18GB_OPTIMIZATION.md` | Technical optimization details |
| `DISK_SPACE_TROUBLESHOOTING.md` | Disk space issue solutions |

## Quick Start (Recommended)

### 1. Configure the Workflow
Edit `workflow_local_to_vps.sh` and update these values:
```bash
LOCAL_SERVER_IP="192.168.1.100"    # Your local Ubuntu server IP
LOCAL_SERVER_USER="username"       # Username on local server  
VPS_IP="194.238.17.65"            # Your production VPS
VPS_USER="user"                    # Username on VPS
```

### 2. Run Complete Workflow
```bash
./workflow_local_to_vps.sh
```

This will automatically:
- ✅ Deploy scripts to your local server
- ✅ Check server resources (RAM/disk)
- ✅ Run CTGAN data generation
- ✅ Pull generated data back to dev machine
- ✅ Deploy data to VPS
- ✅ Extract and organize for RAG system

## Alternative Workflows

### Option A: Manual Step-by-Step

#### Step 1: Deploy to Local Server
```bash
# Upload generation script to local server
scp ubuntu_data_generator.sh username@192.168.1.100:~/
scp *.md username@192.168.1.100:~/

# SSH to local server
ssh username@192.168.1.100
chmod +x ubuntu_data_generator.sh
```

#### Step 2: Run Generation on Local Server
```bash
# On local server - run data generation
./ubuntu_data_generator.sh

# Monitor progress (in another terminal)
tail -f ~/laika-data-generator/generation.log
```

#### Step 3: Pull Data Back to Dev Machine
```bash
# From dev machine - pull generated data
mkdir -p ./generated_data
scp username@192.168.1.100:~/laika-data-generator/laika-dynamics-synthetic-data.tar.gz ./generated_data/
```

#### Step 4: Deploy to VPS
```bash
# Deploy to VPS
./deploy_generated_data_to_vps.sh
```

### Option B: Background Generation

If you want to run generation in background and pull later:

```bash
# Start workflow but run generation in background
./workflow_local_to_vps.sh
# Choose 'y' when asked "Run in background?"

# Later, when generation is complete, pull and deploy
./workflow_local_to_vps.sh --pull-only
```

### Option C: Direct VPS Generation (Not Recommended)

If you want to generate directly on VPS (limited by VPS resources):
```bash
# Edit deploy_to_server.sh to use VPS IP
nano deploy_to_server.sh

# Deploy and run on VPS
./deploy_to_server.sh
```

## Monitoring Generation Progress

### Real-time Monitoring
```bash
# Watch generation log
ssh username@192.168.1.100 'tail -f ~/laika-data-generator/generation.log'

# Monitor system resources
ssh username@192.168.1.100 'watch "free -h && df -h /"'

# Check if generation is still running
ssh username@192.168.1.100 'pgrep -f ubuntu_data_generator.sh'
```

### Expected Timeline
| Server Specs | Generation Time | Peak Memory | Disk Usage |
|--------------|----------------|-------------|------------|
| 16GB RAM + SSD | 45-60 minutes | ~12GB | ~8GB |
| 24GB RAM + SSD | 30-45 minutes | ~14GB | ~10GB |
| 32GB RAM + NVMe | 20-35 minutes | ~16GB | ~12GB |

## Generated Data Structure

After successful generation, you'll have:

```
generated_data/
├── laika-dynamics-synthetic-data.tar.gz   # Main data package
├── dataset_summary.json                   # Generation statistics  
└── generation.log                         # Generation log

# Inside the tar.gz:
data/synthetic/
├── clients.csv              # ~800-3,000 client records
├── projects.csv             # ~3,500-15,000 project records  
├── team_members.csv         # ~45-200 team member records
├── project_assignments.csv  # ~10,000-50,000 assignment records
├── tickets.csv              # ~25,000-100,000 ticket records
├── invoices.csv             # ~15,000-75,000 invoice records
├── contracts.csv            # ~2,000-10,000 contract records
└── dataset_summary.json     # Metadata and statistics
```

## Troubleshooting

### Common Issues

#### 1. "No space left on device"
```bash
# Clean up local server
ssh username@192.168.1.100 'sudo apt-get clean && sudo apt-get autoremove -y'

# The script now automatically handles this
```

#### 2. Python version not found
```bash
# Script auto-detects Python 3.10, 3.11, 3.12
# Manually check available versions:
ssh username@192.168.1.100 'python3 --version'
```

#### 3. Generation fails/hangs
```bash
# Check system resources
ssh username@192.168.1.100 'htop'

# Check generation log for errors
ssh username@192.168.1.100 'tail -50 ~/laika-data-generator/generation.log'

# Kill and restart if needed
ssh username@192.168.1.100 'pkill -f ubuntu_data_generator.sh'
```

#### 4. Network connectivity issues
```bash
# Test connectivity
ping 192.168.1.100        # Local server
ping 194.238.17.65         # VPS

# Check SSH access
ssh username@192.168.1.100 'echo "Local server OK"'
ssh user@194.238.17.65 'echo "VPS OK"'
```

### Recovery Commands

#### Clean up after failed generation:
```bash
# On local server
ssh username@192.168.1.100 'rm -rf ~/laika-data-generator && rm -f ~/ubuntu_data_generator.sh'

# On dev machine  
rm -rf ./generated_data
```

#### Re-run specific parts:
```bash
# Just pull and deploy (if generation already completed)
./workflow_local_to_vps.sh --pull-only

# Just deploy existing data to VPS
./deploy_generated_data_to_vps.sh
```

## Integration with RAG System

After deployment to VPS, the data will be in:
```
~/laika-dynamics-rag/data/synthetic/
```

### Restart RAG Services
```bash
# Docker Compose
ssh user@194.238.17.65 'cd ~/laika-dynamics-rag && docker-compose restart'

# Systemd service
ssh user@194.238.17.65 'sudo systemctl restart laika-rag-service'

# Manual restart (adjust for your setup)
ssh user@194.238.17.65 'pkill -f rag && cd ~/laika-dynamics-rag && python main.py &'
```

### Verify Integration
```bash
# Check data files
ssh user@194.238.17.65 'ls -la ~/laika-dynamics-rag/data/synthetic/'

# Check record counts
ssh user@194.238.17.65 'wc -l ~/laika-dynamics-rag/data/synthetic/*.csv'

# Test RAG endpoint (adjust URL for your setup)
curl http://194.238.17.65:8000/health
```

## Performance Optimization Tips

### Local Server Optimization
- **Use SSD/NVMe storage** for faster I/O
- **Close unnecessary applications** during generation
- **Ensure good cooling** - generation is CPU intensive
- **Use wired network** for faster file transfers

### Network Optimization
- **Use SSH key authentication** to avoid password prompts
- **Enable SSH connection multiplexing** for faster transfers
- **Consider using rsync** instead of scp for large files

### VPS Integration
- **Stop RAG services** during data upload to free resources
- **Use symbolic links** if you need to keep multiple data versions
- **Monitor VPS disk space** before deployment

This workflow ensures reliable, automated synthetic data generation and deployment for your RAG system! 