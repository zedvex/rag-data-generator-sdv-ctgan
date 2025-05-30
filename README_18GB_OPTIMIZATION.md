# Laika Dynamics CTGAN Data Generator - 18GB RAM Optimized

## Overview
This script has been optimized to work efficiently within an 18GB RAM limit while maintaining high-quality synthetic data generation using CTGAN.

## Key Optimizations for 18GB RAM

### Memory Management
- **Target Records**: Reduced from 100k to 75k for base configuration
- **Batch Sizes**: Optimized batch sizes (3000 max, 1500 for <18GB, 800 for <12GB)
- **Neural Network Dimensions**: Reduced from (256,256) to (128,128) for both generator and discriminator
- **Memory Environment Variables**: Set conservative memory allocation limits

### Training Parameters
- **Epochs**: Reduced across all tables for faster training with less memory usage
  - Clients: 150 epochs (was 200)
  - Projects: 200 epochs (was 300) 
  - Team Members: 100 epochs (was 150)
  - Assignments: 75 epochs (was 100)
  - Tickets: 120 epochs (was 200)
  - Invoices: 100 epochs (was 150)
  - Contracts: 75 epochs (was 100)

### Base Dataset Sizes
Memory-adaptive base dataset generation:
- **18GB+ RAM**: 800 clients, 45 team members, 3500 projects
- **12-18GB RAM**: 600 clients, 35 team members, 2500 projects  
- **<12GB RAM**: 400 clients, 25 team members, 1500 projects

### Scaling Factors
- **18GB+ RAM**: 2-4x scaling factor (max 120k target records)
- **12-18GB RAM**: 2-3x scaling factor (75k target records)
- **<12GB RAM**: 2x scaling factor (50k target records)

## Features

### Complete Data Pipeline
1. **System Preparation**: Environment setup, dependency installation
2. **Schema Creation**: Comprehensive business data schemas
3. **Base Data Generation**: Realistic seed data with business logic
4. **CTGAN Enhancement**: AI-powered synthetic data expansion
5. **Quality Validation**: Data integrity and relationship checks
6. **Packaging**: Compressed deployment-ready package

### Monitoring & Safety
- Real-time memory usage monitoring
- Performance statistics logging
- Graceful fallback to rule-based generation if CTGAN fails
- Conservative memory allocation to prevent OOM errors

### Output
- 7 related business tables (clients, projects, team_members, etc.)
- CSV format ready for RAG system integration
- Deployment package with upload instructions
- Quality validation reports

## Usage

```bash
# Make executable
chmod +x ubuntu_data_generator.sh

# Run the complete pipeline
./ubuntu_data_generator.sh

# Monitor progress
tail -f ~/laika-data-generator/generation.log
```

## Memory Requirements by Configuration

| RAM Available | Target Records | Expected Peak Usage | Generation Time |
|---------------|----------------|-------------------|-----------------|
| 18GB+         | 120,000        | ~14GB             | 45-60 minutes   |
| 12-18GB       | 75,000         | ~10GB             | 30-45 minutes   |
| 8-12GB        | 50,000         | ~7GB              | 20-30 minutes   |
| <8GB          | 25,000         | ~5GB              | 15-25 minutes   |

## Safety Features
- Automatic memory detection and configuration adjustment
- Conservative batch sizing to prevent memory overflow
- Progress monitoring with memory usage alerts
- Fallback generation methods if CTGAN training fails
- Comprehensive error handling and logging

## Output Files
```
~/laika-data-generator/
├── data/synthetic/
│   ├── clients.csv
│   ├── projects.csv
│   ├── team_members.csv
│   ├── project_assignments.csv
│   ├── tickets.csv
│   ├── invoices.csv
│   ├── contracts.csv
│   └── dataset_summary.json
├── laika-dynamics-synthetic-data.tar.gz
├── upload_instructions.txt
└── generation.log
```

This optimized version ensures reliable execution within 18GB RAM limits while producing high-quality, business-realistic synthetic data suitable for RAG system training and evaluation. 