#!/bin/bash

# Laika Dynamics CTGAN Data Generator for Ubuntu Server
# Optimized for 18GB RAM and high-quality synthetic data generation

set -e

# Configuration
PROJECT_DIR="$HOME/laika-data-generator"
VENV_NAME="ctgan-env"
# Auto-detect available Python version
if command -v python3.12 &> /dev/null; then
    PYTHON_VERSION="3.12"
elif command -v python3.11 &> /dev/null; then
    PYTHON_VERSION="3.11"
elif command -v python3.10 &> /dev/null; then
    PYTHON_VERSION="3.10"
else
    PYTHON_VERSION="3"
fi
TARGET_RECORDS=75000  # Optimized for 18GB RAM
VPS_IP="194.238.17.65"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check Ubuntu system requirements
check_system() {
    log "Checking Ubuntu system requirements..."
    
    # Check memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ $MEMORY_GB -lt 16 ]; then
        warn "System has ${MEMORY_GB}GB RAM. 18GB recommended for optimal CTGAN performance."
    else
        log "Memory check passed: ${MEMORY_GB}GB available"
    fi
    
    # Check disk space
    DISK_FREE_GB=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    log "Available disk space: ${DISK_FREE_GB}GB"
    
    if [ $DISK_FREE_GB -lt 10 ]; then
        error "Insufficient disk space. Need at least 10GB free. Available: ${DISK_FREE_GB}GB"
    elif [ $DISK_FREE_GB -lt 15 ]; then
        warn "Low disk space detected: ${DISK_FREE_GB}GB. Consider freeing up space."
        log "Installing with minimal dependencies..."
        MINIMAL_INSTALL=true
    else
        log "Disk space check passed: ${DISK_FREE_GB}GB available"
        MINIMAL_INSTALL=false
    fi
    
    # Check GPU
    if command -v nvidia-smi &> /dev/null; then
        log "NVIDIA GPU detected:"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        GPU_AVAILABLE=true
    else
        log "No GPU detected - will use CPU (slower but still works)"
        GPU_AVAILABLE=false
    fi
    
    # Update system
    log "Updating Ubuntu packages..."
    sudo apt-get update -y
    sudo apt-get install -y python3 python3-pip python3-venv build-essential git wget curl
}

# Cleanup function to free disk space
cleanup_system() {
    log "Cleaning up system to free disk space..."
    
    # Clean package cache
    sudo apt-get clean
    sudo apt-get autoremove -y
    
    # Clean pip cache
    if command -v pip3 &> /dev/null; then
        pip3 cache purge || true
    fi
    
    # Remove temporary files
    sudo rm -rf /tmp/* || true
    sudo rm -rf /var/tmp/* || true
    
    # Show available space after cleanup
    DISK_FREE_AFTER=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    log "Disk space after cleanup: ${DISK_FREE_AFTER}GB"
}

# Setup project directory
setup_project() {
    log "Setting up data generation project..."
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    mkdir -p {data/real_samples,data/synthetic,data/schemas,scripts,exports}
}

# Setup Python environment with GPU support
setup_python_env() {
    log "Setting up Python environment for CTGAN..."
    log "Detected Python version: $PYTHON_VERSION"
    cd "$PROJECT_DIR"
    
    # Check if the detected Python version actually works
    if ! command -v python$PYTHON_VERSION &> /dev/null; then
        error "Python $PYTHON_VERSION not found. Please install it first."
    fi
    
    # Clean up before starting
    cleanup_system
    
    python$PYTHON_VERSION -m venv $VENV_NAME
    source $VENV_NAME/bin/activate
    
    pip install --upgrade pip
    
    # Install CTGAN and dependencies with disk space optimization
    log "Installing ML dependencies (optimized for disk space)..."
    
    if [ "$MINIMAL_INSTALL" = true ]; then
        # Minimal installation for low disk space
        log "Using minimal installation due to disk space constraints..."
        
        # Install PyTorch CPU-only (smaller)
        pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        
        # Install essential packages only
        pip install --no-cache-dir \
            pandas \
            numpy \
            faker \
            psutil \
            tqdm \
            ctgan
            
        log "Minimal installation completed. Some visualization features may be limited."
        
    else
        # Full installation
        if [ "$GPU_AVAILABLE" = true ]; then
            # GPU version
            pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
        else
            # CPU version
            pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        fi
        
        # Install in batches to manage disk space
        log "Installing core ML packages..."
        pip install --no-cache-dir \
            pandas \
            numpy \
            faker \
            psutil \
            tqdm \
            ctgan
        
        log "Installing additional packages..."
        pip install --no-cache-dir \
            sdv[tabular] \
            matplotlib \
            seaborn \
            scipy \
            scikit-learn
        
        log "Installing utility packages..."    
        pip install --no-cache-dir \
            jupyter \
            plotly \
            openpyxl \
            requests
    fi
    
    # Clean up pip cache after installation
    pip cache purge || true
    
    log "Python environment setup completed successfully!"
}

# Create realistic seed data schemas
create_schemas() {
    log "Creating comprehensive business data schemas..."
    
    cat > data/schemas/web_contracting_schema.yaml << 'EOF'
# Laika Dynamics Web Contracting Business Schema
# Designed for realistic B2B consulting relationships

tables:
  clients:
    primary_key: client_id
    relationships:
      - has_many: projects
      - has_many: invoices
      - has_many: contracts
    columns:
      client_id:
        type: categorical
        description: "Unique client identifier"
      company_name:
        type: text
        description: "Business name"
      industry:
        type: categorical
        categories: 
          - "Technology"
          - "Healthcare" 
          - "Financial Services"
          - "E-commerce"
          - "Manufacturing"
          - "Education"
          - "Government"
          - "Non-profit"
          - "Real Estate"
          - "Media & Entertainment"
      company_size:
        type: categorical
        categories: ["Startup", "SMB", "Mid-market", "Enterprise"]
      annual_revenue:
        type: numerical
        min: 50000
        max: 50000000
        distribution: "log-normal"
      headquarters_country:
        type: categorical
        categories: ["USA", "Canada", "UK", "Germany", "Australia", "France", "Netherlands"]
      contact_email:
        type: email
      phone:
        type: phone
      website:
        type: url
      acquisition_channel:
        type: categorical
        categories: ["Referral", "Website", "LinkedIn", "Conference", "Cold Outreach", "Partner"]
      risk_score:
        type: numerical
        min: 0.1
        max: 1.0
        distribution: "beta"
      monthly_retainer:
        type: numerical
        min: 5000
        max: 100000
        distribution: "exponential"
      client_since:
        type: datetime
        start: "2020-01-01"
        end: "2024-12-31"

  projects:
    primary_key: project_id
    foreign_keys:
      - column: client_id
        references: clients.client_id
    columns:
      project_id:
        type: categorical
      client_id:
        type: categorical
      project_name:
        type: text
        description: "Descriptive project title"
      project_type:
        type: categorical
        categories:
          - "Web Application"
          - "Mobile App"
          - "API Development"
          - "Data Analytics Platform"
          - "E-commerce Site"
          - "CRM System"
          - "DevOps Setup"
          - "AI/ML Solution"
          - "Cloud Migration"
          - "Security Audit"
      tech_stack:
        type: categorical
        categories:
          - "React/Node.js/PostgreSQL"
          - "Python/Django/MySQL"
          - "Java/Spring/Oracle"
          - "PHP/Laravel/MariaDB"
          - "Ruby/Rails/Redis"
          - ".NET/C#/SQL Server"
          - "Vue.js/Express/MongoDB"
          - "Angular/NestJS/GraphQL"
      project_status:
        type: categorical
        categories: ["Discovery", "Planning", "Development", "Testing", "Deployment", "Completed", "On Hold", "Cancelled"]
      priority:
        type: categorical
        categories: ["Low", "Medium", "High", "Critical"]
      start_date:
        type: datetime
        start: "2022-01-01"
        end: "2024-12-31"
      planned_end_date:
        type: datetime
        start: "2022-02-01"
        end: "2025-06-30"
      actual_end_date:
        type: datetime
        start: "2022-02-01"
        end: "2025-06-30"
        nullable: true
      budget_original:
        type: numerical
        min: 10000
        max: 2000000
        distribution: "log-normal"
      budget_current:
        type: numerical
        min: 8000
        max: 2500000
        distribution: "log-normal"
      hours_estimated:
        type: numerical
        min: 40
        max: 5000
        distribution: "gamma"
      hours_actual:
        type: numerical
        min: 20
        max: 6000
        distribution: "gamma"
      team_size:
        type: numerical
        min: 1
        max: 12
        distribution: "poisson"
      complexity_score:
        type: numerical
        min: 1
        max: 10
        distribution: "normal"

  team_members:
    primary_key: member_id
    columns:
      member_id:
        type: categorical
      first_name:
        type: text
      last_name:
        type: text
      role:
        type: categorical
        categories:
          - "Full Stack Developer"
          - "Frontend Developer" 
          - "Backend Developer"
          - "DevOps Engineer"
          - "Data Scientist"
          - "UI/UX Designer"
          - "Project Manager"
          - "QA Engineer"
          - "Solution Architect"
          - "Technical Lead"
      seniority:
        type: categorical
        categories: ["Junior", "Mid-level", "Senior", "Lead", "Principal"]
      hourly_rate:
        type: numerical
        min: 50
        max: 300
        distribution: "normal"
      skills:
        type: text
        description: "Comma-separated technical skills"
      availability:
        type: numerical
        min: 0.2
        max: 1.0
        description: "Fraction of time available (0.2 = 20%)"
      hire_date:
        type: datetime
        start: "2018-01-01"
        end: "2024-12-31"

  project_assignments:
    primary_key: assignment_id
    foreign_keys:
      - column: project_id
        references: projects.project_id
      - column: member_id
        references: team_members.member_id
    columns:
      assignment_id:
        type: categorical
      project_id:
        type: categorical
      member_id:
        type: categorical
      role_on_project:
        type: categorical
        categories: ["Lead", "Developer", "Consultant", "Support"]
      hours_allocated:
        type: numerical
        min: 10
        max: 1000
        distribution: "exponential"
      hours_logged:
        type: numerical
        min: 5
        max: 1200
        distribution: "exponential"
      start_date:
        type: datetime
        start: "2022-01-01"
        end: "2024-12-31"
      end_date:
        type: datetime
        start: "2022-02-01"
        end: "2025-06-30"
        nullable: true

  tickets:
    primary_key: ticket_id
    foreign_keys:
      - column: project_id
        references: projects.project_id
      - column: assignee_id
        references: team_members.member_id
    columns:
      ticket_id:
        type: categorical
      project_id:
        type: categorical
      ticket_title:
        type: text
      ticket_type:
        type: categorical
        categories: ["Feature", "Bug", "Enhancement", "Research", "Documentation", "Testing"]
      priority:
        type: categorical
        categories: ["Low", "Medium", "High", "Critical"]
      status:
        type: categorical
        categories: ["Backlog", "In Progress", "Review", "Testing", "Done", "Blocked"]
      assignee_id:
        type: categorical
      story_points:
        type: categorical
        categories: [1, 2, 3, 5, 8, 13, 21]
      created_date:
        type: datetime
        start: "2022-01-01"
        end: "2024-12-31"
      completed_date:
        type: datetime
        start: "2022-01-01"
        end: "2025-03-31"
        nullable: true
      estimated_hours:
        type: numerical
        min: 0.5
        max: 40
        distribution: "exponential"
      actual_hours:
        type: numerical
        min: 0.25
        max: 60
        distribution: "exponential"

  invoices:
    primary_key: invoice_id
    foreign_keys:
      - column: client_id
        references: clients.client_id
      - column: project_id
        references: projects.project_id
    columns:
      invoice_id:
        type: categorical
      client_id:
        type: categorical
      project_id:
        type: categorical
        nullable: true
      invoice_type:
        type: categorical
        categories: ["Milestone", "Monthly Retainer", "Time & Materials", "Fixed Price"]
      invoice_date:
        type: datetime
        start: "2022-01-01"
        end: "2024-12-31"
      due_date:
        type: datetime
        start: "2022-01-15"
        end: "2025-01-31"
      amount_gross:
        type: numerical
        min: 1000
        max: 500000
        distribution: "log-normal"
      tax_amount:
        type: numerical
        min: 0
        max: 50000
        distribution: "exponential"
      amount_net:
        type: numerical
        min: 800
        max: 450000
        distribution: "log-normal"
      payment_status:
        type: categorical
        categories: ["Draft", "Sent", "Paid", "Overdue", "Cancelled"]
      payment_date:
        type: datetime
        start: "2022-01-01"
        end: "2025-01-31"
        nullable: true
      payment_method:
        type: categorical
        categories: ["Bank Transfer", "Credit Card", "PayPal", "Check", "Crypto"]

  contracts:
    primary_key: contract_id
    foreign_keys:
      - column: client_id
        references: clients.client_id
    columns:
      contract_id:
        type: categorical
      client_id:
        type: categorical
      contract_type:
        type: categorical
        categories: ["Master Service Agreement", "Statement of Work", "Retainer Agreement", "NDA", "Consulting Agreement"]
      start_date:
        type: datetime
        start: "2020-01-01"
        end: "2024-12-31"
      end_date:
        type: datetime
        start: "2020-06-01"
        end: "2026-12-31"
      contract_value:
        type: numerical
        min: 25000
        max: 5000000
        distribution: "log-normal"
      renewal_terms:
        type: categorical
        categories: ["Auto-renew", "Manual Renewal", "One-time", "Evergreen"]
      status:
        type: categorical
        categories: ["Draft", "Under Review", "Active", "Expired", "Terminated"]
EOF
}

# Create advanced CTGAN data generator
create_ctgan_generator() {
    log "Creating advanced CTGAN data generator..."
    
    cat > scripts/generate_enterprise_data.py << 'EOF'
#!/usr/bin/env python3
"""
Laika Dynamics Enterprise Data Generator
Advanced CTGAN-based synthetic data generation for web contracting business
"""

import pandas as pd
import numpy as np
from faker import Faker
from datetime import datetime, timedelta
import random
import os
import sys
from typing import Dict, List, Any
import psutil
import time
from tqdm import tqdm

# ML imports
from ctgan import CTGAN
from sdv.metadata import SingleTableMetadata
from sdv.single_table import CTGANSynthesizer
import warnings
warnings.filterwarnings('ignore')

class LaikaDynamicsDataGenerator:
    """Enterprise-grade synthetic data generator"""
    
    def __init__(self, target_records: int = 100000):
        self.target_records = target_records
        self.fake = Faker(['en_US', 'en_GB', 'en_CA'])
        self.output_dir = '../data/synthetic'
        self.real_samples_dir = '../data/real_samples'
        
        # Ensure output directories exist
        os.makedirs(self.output_dir, exist_ok=True)
        os.makedirs(self.real_samples_dir, exist_ok=True)
        
        self.log("Laika Dynamics Data Generator initialized")
        self.log(f"Target records: {target_records:,}")
        self.log(f"Available RAM: {psutil.virtual_memory().total / (1024**3):.1f} GB")
        
    def log(self, message: str):
        """Enhanced logging with timestamps"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {message}")
    
    def create_realistic_clients(self, n_clients: int = 1000) -> pd.DataFrame:
        """Generate realistic client data with business logic"""
        self.log(f"Generating {n_clients:,} client records...")
        
        industries = [
            "Technology", "Healthcare", "Financial Services", "E-commerce",
            "Manufacturing", "Education", "Government", "Non-profit", 
            "Real Estate", "Media & Entertainment"
        ]
        
        company_sizes = ["Startup", "SMB", "Mid-market", "Enterprise"]
        countries = ["USA", "Canada", "UK", "Germany", "Australia", "France", "Netherlands"]
        channels = ["Referral", "Website", "LinkedIn", "Conference", "Cold Outreach", "Partner"]
        
        clients = []
        
        for i in tqdm(range(n_clients), desc="Creating clients"):
            industry = random.choice(industries)
            company_size = random.choice(company_sizes)
            
            # Revenue correlates with company size
            revenue_ranges = {
                "Startup": (50000, 2000000),
                "SMB": (500000, 10000000), 
                "Mid-market": (10000000, 100000000),
                "Enterprise": (100000000, 50000000000)
            }
            
            min_rev, max_rev = revenue_ranges[company_size]
            annual_revenue = random.randint(min_rev, max_rev)
            
            # Retainer correlates with revenue
            monthly_retainer = min(100000, max(5000, int(annual_revenue * 0.001 * random.uniform(0.5, 2.0))))
            
            # Risk score based on various factors
            risk_factors = []
            if company_size == "Startup":
                risk_factors.append(0.3)
            if industry in ["Government", "Healthcare"]:
                risk_factors.append(-0.2)
            if annual_revenue < 1000000:
                risk_factors.append(0.2)
                
            base_risk = 0.5
            risk_score = max(0.1, min(1.0, base_risk + sum(risk_factors) + random.uniform(-0.2, 0.2)))
            
            client = {
                'client_id': f'CLT_{i:06d}',
                'company_name': self.fake.company(),
                'industry': industry,
                'company_size': company_size,
                'annual_revenue': annual_revenue,
                'headquarters_country': random.choice(countries),
                'contact_email': self.fake.company_email(),
                'phone': self.fake.phone_number(),
                'website': f"https://{self.fake.domain_name()}",
                'acquisition_channel': random.choice(channels),
                'risk_score': round(risk_score, 3),
                'monthly_retainer': monthly_retainer,
                'client_since': self.fake.date_between(start_date='-4y', end_date='today')
            }
            clients.append(client)
        
        return pd.DataFrame(clients)
    
    def create_realistic_team_members(self, n_members: int = 50) -> pd.DataFrame:
        """Generate realistic team member data"""
        self.log(f"Generating {n_members} team members...")
        
        roles = [
            "Full Stack Developer", "Frontend Developer", "Backend Developer",
            "DevOps Engineer", "Data Scientist", "UI/UX Designer", 
            "Project Manager", "QA Engineer", "Solution Architect", "Technical Lead"
        ]
        
        seniorities = ["Junior", "Mid-level", "Senior", "Lead", "Principal"]
        
        # Rate ranges by role and seniority
        base_rates = {
            "Junior": (50, 80),
            "Mid-level": (80, 120),
            "Senior": (120, 180),
            "Lead": (150, 220),
            "Principal": (200, 300)
        }
        
        skill_sets = {
            "Full Stack Developer": ["JavaScript", "React", "Node.js", "Python", "SQL"],
            "Frontend Developer": ["React", "Vue.js", "Angular", "CSS", "TypeScript"],
            "Backend Developer": ["Python", "Java", "Node.js", "PostgreSQL", "Redis"],
            "DevOps Engineer": ["AWS", "Docker", "Kubernetes", "Terraform", "Jenkins"],
            "Data Scientist": ["Python", "R", "TensorFlow", "SQL", "Tableau"],
            "UI/UX Designer": ["Figma", "Sketch", "Adobe XD", "Prototyping", "User Research"],
            "Project Manager": ["Agile", "Scrum", "JIRA", "Risk Management", "Stakeholder Management"],
            "QA Engineer": ["Selenium", "Jest", "Cypress", "Manual Testing", "API Testing"],
            "Solution Architect": ["System Design", "Cloud Architecture", "Microservices", "APIs"],
            "Technical Lead": ["Leadership", "Code Review", "Architecture", "Mentoring"]
        }
        
        members = []
        
        for i in range(n_members):
            role = random.choice(roles)
            seniority = random.choice(seniorities)
            
            min_rate, max_rate = base_rates[seniority]
            # Add role premium for specialized roles
            if role in ["Solution Architect", "Technical Lead", "Data Scientist"]:
                min_rate = int(min_rate * 1.2)
                max_rate = int(max_rate * 1.2)
            
            member = {
                'member_id': f'TM_{i:04d}',
                'first_name': self.fake.first_name(),
                'last_name': self.fake.last_name(),
                'role': role,
                'seniority': seniority,
                'hourly_rate': random.randint(min_rate, max_rate),
                'skills': ', '.join(skill_sets.get(role, ["General"])),
                'availability': round(random.uniform(0.5, 1.0), 2),
                'hire_date': self.fake.date_between(start_date='-6y', end_date='today')
            }
            members.append(member)
        
        return pd.DataFrame(members)
    
    def create_realistic_projects(self, clients_df: pd.DataFrame, n_projects: int = 5000) -> pd.DataFrame:
        """Generate realistic project data with business relationships"""
        self.log(f"Generating {n_projects:,} projects...")
        
        project_types = [
            "Web Application", "Mobile App", "API Development", 
            "Data Analytics Platform", "E-commerce Site", "CRM System",
            "DevOps Setup", "AI/ML Solution", "Cloud Migration", "Security Audit"
        ]
        
        tech_stacks = [
            "React/Node.js/PostgreSQL", "Python/Django/MySQL", "Java/Spring/Oracle",
            "PHP/Laravel/MariaDB", "Ruby/Rails/Redis", ".NET/C#/SQL Server",
            "Vue.js/Express/MongoDB", "Angular/NestJS/GraphQL"
        ]
        
        statuses = ["Discovery", "Planning", "Development", "Testing", "Deployment", "Completed", "On Hold", "Cancelled"]
        priorities = ["Low", "Medium", "High", "Critical"]
        
        projects = []
        
        for i in tqdm(range(n_projects), desc="Creating projects"):
            # Select client with bias toward larger clients having more projects
            client = clients_df.sample(weights=clients_df['annual_revenue']).iloc[0]
            
            project_type = random.choice(project_types)
            tech_stack = random.choice(tech_stacks)
            
            # Project complexity affects budget and timeline
            complexity = random.randint(1, 10)
            
            # Budget correlates with client size and complexity
            base_budget = client['monthly_retainer'] * random.uniform(0.5, 3.0) * (complexity / 5)
            budget_original = int(base_budget * random.uniform(0.8, 1.5))
            budget_current = int(budget_original * random.uniform(0.9, 1.3))
            
            # Hours estimation
            hours_estimated = int(budget_original / 150)  # Assuming $150/hour average
            hours_actual = int(hours_estimated * random.uniform(0.7, 1.4))
            
            start_date = self.fake.date_between(start_date='-2y', end_date='today')
            planned_duration = timedelta(days=complexity * 30 + random.randint(14, 90))
            planned_end = start_date + planned_duration
            
            # Some projects are completed, others ongoing
            status = random.choice(statuses)
            actual_end = None
            if status == "Completed":
                actual_end = planned_end + timedelta(days=random.randint(-30, 60))
            
            project = {
                'project_id': f'PRJ_{i:06d}',
                'client_id': client['client_id'],
                'project_name': f"{project_type} for {client['company_name'][:20]}",
                'project_type': project_type,
                'tech_stack': tech_stack,
                'project_status': status,
                'priority': random.choice(priorities),
                'start_date': start_date,
                'planned_end_date': planned_end,
                'actual_end_date': actual_end,
                'budget_original': budget_original,
                'budget_current': budget_current,
                'hours_estimated': hours_estimated,
                'hours_actual': hours_actual,
                'team_size': min(12, max(1, complexity // 2 + random.randint(1, 3))),
                'complexity_score': complexity
            }
            projects.append(project)
        
        return pd.DataFrame(projects)
    
    def apply_ctgan_enhancement(self, df: pd.DataFrame, table_name: str, epochs: int = 300) -> pd.DataFrame:
        """Apply CTGAN to enhance dataset realism and scale"""
        self.log(f"Applying CTGAN enhancement to {table_name}...")
        self.log(f"Original dataset: {len(df):,} rows")
        
        try:
            # Configure CTGAN based on available resources (optimized for 18GB RAM)
            batch_size = min(3000, len(df))
            if psutil.virtual_memory().total < 18 * (1024**3):  # Less than 18GB RAM
                batch_size = min(1500, len(df))
                epochs = min(150, epochs)
            elif psutil.virtual_memory().total < 12 * (1024**3):  # Less than 12GB RAM
                batch_size = min(800, len(df))
                epochs = min(100, epochs)
            
            # Initialize CTGAN with memory-optimized settings
            ctgan = CTGAN(
                epochs=epochs,
                batch_size=batch_size,
                generator_dim=(128, 128),  # Reduced from (256, 256) for 18GB RAM
                discriminator_dim=(128, 128),  # Reduced from (256, 256) for 18GB RAM
                verbose=True
            )
            
            # Train the model
            self.log(f"Training CTGAN model with {epochs} epochs and batch size {batch_size}...")
            start_time = time.time()
            ctgan.fit(df)
            training_time = time.time() - start_time
            self.log(f"Training completed in {training_time:.1f} seconds")
            
            # Generate synthetic data with conservative scaling for 18GB RAM
            memory_gb = psutil.virtual_memory().total / (1024**3)
            if memory_gb >= 18:
                scale_factor = max(2, min(4, self.target_records // len(df)))
            elif memory_gb >= 12:
                scale_factor = max(2, min(3, self.target_records // len(df)))
            else:
                scale_factor = 2
                
            synthetic_size = len(df) * scale_factor
            
            self.log(f"Generating {synthetic_size:,} synthetic records...")
            synthetic_df = ctgan.sample(synthetic_size)
            
            # Post-process to ensure data quality
            synthetic_df = self._post_process_synthetic_data(synthetic_df, df)
            
            self.log(f"Enhanced dataset: {len(synthetic_df):,} rows ({len(synthetic_df)/len(df):.1f}x increase)")
            
            return synthetic_df
            
        except Exception as e:
            self.log(f"CTGAN enhancement failed: {str(e)}")
            self.log("Falling back to rule-based scaling...")
            return self._fallback_scaling(df, scale_factor=3)
    
    def _post_process_synthetic_data(self, synthetic_df: pd.DataFrame, original_df: pd.DataFrame) -> pd.DataFrame:
        """Clean and validate synthetic data"""
        # Ensure numeric columns are within reasonable bounds
        for col in synthetic_df.select_dtypes(include=[np.number]).columns:
            if col in original_df.columns:
                min_val = original_df[col].min() * 0.1
                max_val = original_df[col].max() * 2.0
                synthetic_df[col] = synthetic_df[col].clip(lower=min_val, upper=max_val)
        
        # Clean up categorical data
        for col in synthetic_df.select_dtypes(include=['object']).columns:
            if col in original_df.columns:
                valid_values = original_df[col].unique()
                # Replace invalid synthetic values with random valid ones
                invalid_mask = ~synthetic_df[col].isin(valid_values)
                if invalid_mask.any():
                    synthetic_df.loc[invalid_mask, col] = np.random.choice(
                        valid_values, size=invalid_mask.sum()
                    )
        
        return synthetic_df
    
    def _fallback_scaling(self, df: pd.DataFrame, scale_factor: int = 3) -> pd.DataFrame:
        """Fallback method if CTGAN fails"""
        self.log("Using rule-based data multiplication...")
        
        # Simple replication with noise
        scaled_dfs = []
        for i in range(scale_factor):
            df_copy = df.copy()
            
            # Add noise to numeric columns
            for col in df_copy.select_dtypes(include=[np.number]).columns:
                if col not in ['client_id', 'project_id', 'member_id']:  # Skip IDs
                    noise = np.random.normal(0, df_copy[col].std() * 0.1, len(df_copy))
                    df_copy[col] = df_copy[col] + noise
                    df_copy[col] = df_copy[col].clip(lower=df_copy[col].min())
            
            # Update IDs to be unique
            for col in df_copy.columns:
                if col.endswith('_id'):
                    df_copy[col] = df_copy[col].str.replace(r'(\d+)', lambda m: f"{int(m.group(1)) + i * len(df):06d}", regex=True)
            
            scaled_dfs.append(df_copy)
        
        return pd.concat(scaled_dfs, ignore_index=True)
    
    def generate_complete_dataset(self):
        """Generate the complete Laika Dynamics dataset"""
        self.log("Starting complete dataset generation...")
        start_time = time.time()
        
        # Phase 1: Generate base realistic data (optimized for 18GB RAM)
        self.log("=== Phase 1: Base Data Generation ===")
        
        # Adjust base sizes based on available memory
        memory_gb = psutil.virtual_memory().total / (1024**3)
        if memory_gb >= 18:
            base_clients = 800
            base_team = 45
            base_projects = 3500
        elif memory_gb >= 12:
            base_clients = 600
            base_team = 35
            base_projects = 2500
        else:
            base_clients = 400
            base_team = 25
            base_projects = 1500
        
        clients_df = self.create_realistic_clients(base_clients)
        team_df = self.create_realistic_team_members(base_team)
        projects_df = self.create_realistic_projects(clients_df, base_projects)
        
        # Save base data as samples
        clients_df.to_csv(f'{self.real_samples_dir}/clients_base.csv', index=False)
        team_df.to_csv(f'{self.real_samples_dir}/team_members_base.csv', index=False)
        projects_df.to_csv(f'{self.real_samples_dir}/projects_base.csv', index=False)
        
        # Phase 2: CTGAN Enhancement (optimized epochs for 18GB RAM)
        self.log("=== Phase 2: CTGAN Enhancement ===")
        
        # Enhance each table with CTGAN using optimized epoch counts
        enhanced_clients = self.apply_ctgan_enhancement(clients_df, "clients", epochs=150)  # Reduced from 200
        enhanced_team = self.apply_ctgan_enhancement(team_df, "team_members", epochs=100)  # Reduced from 150
        enhanced_projects = self.apply_ctgan_enhancement(projects_df, "projects", epochs=200)  # Reduced from 300
        
        # Phase 3: Generate dependent data
        self.log("=== Phase 3: Dependent Data Generation ===")
        
        # Generate project assignments
        assignments_df = self.create_project_assignments(enhanced_projects, enhanced_team)
        enhanced_assignments = self.apply_ctgan_enhancement(assignments_df, "assignments", epochs=75)  # Reduced from 100
        
        # Generate tickets
        tickets_df = self.create_tickets(enhanced_projects, enhanced_team)
        enhanced_tickets = self.apply_ctgan_enhancement(tickets_df, "tickets", epochs=120)  # Reduced from 200
        
        # Generate invoices
        invoices_df = self.create_invoices(enhanced_clients, enhanced_projects)
        enhanced_invoices = self.apply_ctgan_enhancement(invoices_df, "invoices", epochs=100)  # Reduced from 150
        
        # Generate contracts
        contracts_df = self.create_contracts(enhanced_clients)
        enhanced_contracts = self.apply_ctgan_enhancement(contracts_df, "contracts", epochs=75)  # Reduced from 100
        
        # Phase 4: Export final dataset
        self.log("=== Phase 4: Export & Validation ===")
        
        final_datasets = {
            'clients': enhanced_clients,
            'team_members': enhanced_team,
            'projects': enhanced_projects,
            'project_assignments': enhanced_assignments,
            'tickets': enhanced_tickets,
            'invoices': enhanced_invoices,
            'contracts': enhanced_contracts
        }
        
        self.export_datasets(final_datasets)
        self.validate_datasets(final_datasets)
        
        total_time = time.time() - start_time
        self.log(f"Dataset generation completed in {total_time:.1f} seconds")
        
        return final_datasets
    
    def create_project_assignments(self, projects_df: pd.DataFrame, team_df: pd.DataFrame) -> pd.DataFrame:
        """Generate realistic project assignments"""
        self.log("Generating project assignments...")
        
        assignments = []
        assignment_id = 0
        
        for _, project in projects_df.iterrows():
            team_size = min(project['team_size'], len(team_df))
            assigned_members = team_df.sample(n=team_size)
            
            for _, member in assigned_members.iterrows():
                role_on_project = random.choice(["Lead", "Developer", "Consultant", "Support"])
                
                # Hours allocation based on role and project complexity
                base_hours = project['hours_estimated'] / team_size
                if role_on_project == "Lead":
                    hours_allocated = int(base_hours * random.uniform(1.2, 1.5))
                else:
                    hours_allocated = int(base_hours * random.uniform(0.8, 1.2))
                
                hours_logged = int(hours_allocated * random.uniform(0.7, 1.3))
                
                assignment = {
                    'assignment_id': f'ASN_{assignment_id:06d}',
                    'project_id': project['project_id'],
                    'member_id': member['member_id'],
                    'role_on_project': role_on_project,
                    'hours_allocated': hours_allocated,
                    'hours_logged': hours_logged,
                    'start_date': project['start_date'],
                    'end_date': project['actual_end_date'] if project['actual_end_date'] else None
                }
                assignments.append(assignment)
                assignment_id += 1
        
        return pd.DataFrame(assignments)
    
    def create_tickets(self, projects_df: pd.DataFrame, team_df: pd.DataFrame) -> pd.DataFrame:
        """Generate realistic tickets/tasks"""
        self.log("Generating tickets...")
        
        ticket_types = ["Feature", "Bug", "Enhancement", "Research", "Documentation", "Testing"]
        priorities = ["Low", "Medium", "High", "Critical"]
        statuses = ["Backlog", "In Progress", "Review", "Testing", "Done", "Blocked"]
        story_points = [1, 2, 3, 5, 8, 13, 21]
        
        tickets = []
        ticket_id = 0
        
        for _, project in projects_df.iterrows():
            # Number of tickets based on project complexity and hours
            num_tickets = max(5, int(project['hours_estimated'] / 20))
            
            for i in range(num_tickets):
                ticket_type = random.choice(ticket_types)
                assignee = team_df.sample().iloc[0]
                
                # Story points distribution
                points = random.choice(story_points)
                estimated_hours = points * random.uniform(2, 6)
                actual_hours = estimated_hours * random.uniform(0.5, 1.8)
                
                # Ticket timeline within project timeline
                created_date = project['start_date'] + timedelta(
                    days=random.randint(0, max(1, (project['planned_end_date'] - project['start_date']).days // 2))
                )
                
                status = random.choice(statuses)
                completed_date = None
                if status == "Done":
                    completed_date = created_date + timedelta(days=random.randint(1, 14))
                
                ticket = {
                    'ticket_id': f'TKT_{ticket_id:06d}',
                    'project_id': project['project_id'],
                    'ticket_title': f"{ticket_type}: {self.fake.catch_phrase()}",
                    'ticket_type': ticket_type,
                    'priority': random.choice(priorities),
                    'status': status,
                    'assignee_id': assignee['member_id'],
                    'story_points': points,
                    'created_date': created_date,
                    'completed_date': completed_date,
                    'estimated_hours': round(estimated_hours, 2),
                    'actual_hours': round(actual_hours, 2)
                }
                tickets.append(ticket)
                ticket_id += 1
        
        return pd.DataFrame(tickets)
    
    def create_invoices(self, clients_df: pd.DataFrame, projects_df: pd.DataFrame) -> pd.DataFrame:
        """Generate realistic invoices"""
        self.log("Generating invoices...")
        
        invoice_types = ["Milestone", "Monthly Retainer", "Time & Materials", "Fixed Price"]
        payment_statuses = ["Draft", "Sent", "Paid", "Overdue", "Cancelled"]
        payment_methods = ["Bank Transfer", "Credit Card", "PayPal", "Check", "Crypto"]
        
        invoices = []
        invoice_id = 0
        
        # Generate retainer invoices
        for _, client in clients_df.iterrows():
            if client['monthly_retainer'] > 0:
                # Generate 12-24 months of retainer invoices
                num_months = random.randint(12, 24)
                start_date = client['client_since']
                
                for month in range(num_months):
                    invoice_date = start_date + timedelta(days=month * 30)
                    if invoice_date <= datetime.now().date():
                        
                        amount_gross = client['monthly_retainer']
                        tax_rate = random.uniform(0.08, 0.15)  # 8-15% tax
                        tax_amount = amount_gross * tax_rate
                        amount_net = amount_gross - tax_amount
                        
                        status = random.choices(
                            payment_statuses,
                            weights=[5, 10, 70, 10, 5]  # Most invoices are paid
                        )[0]
                        
                        payment_date = None
                        if status == "Paid":
                            payment_date = invoice_date + timedelta(days=random.randint(1, 30))
                        elif status == "Overdue":
                            payment_date = None
                        
                        invoice = {
                            'invoice_id': f'INV_{invoice_id:06d}',
                            'client_id': client['client_id'],
                            'project_id': None,  # Retainer not tied to specific project
                            'invoice_type': "Monthly Retainer",
                            'invoice_date': invoice_date,
                            'due_date': invoice_date + timedelta(days=30),
                            'amount_gross': int(amount_gross),
                            'tax_amount': int(tax_amount),
                            'amount_net': int(amount_net),
                            'payment_status': status,
                            'payment_date': payment_date,
                            'payment_method': random.choice(payment_methods)
                        }
                        invoices.append(invoice)
                        invoice_id += 1
        
        # Generate project-based invoices
        for _, project in projects_df.iterrows():
            if project['project_status'] in ['Completed', 'Development', 'Testing']:
                num_invoices = random.randint(1, 4)  # 1-4 invoices per project
                
                for i in range(num_invoices):
                    invoice_date = project['start_date'] + timedelta(
                        days=random.randint(0, max(1, (project['planned_end_date'] - project['start_date']).days))
                    )
                    
                    invoice_type = random.choice(["Milestone", "Time & Materials", "Fixed Price"])
                    
                    # Amount based on project budget
                    if num_invoices == 1:
                        amount_gross = project['budget_current']
                    else:
                        amount_gross = project['budget_current'] / num_invoices * random.uniform(0.8, 1.2)
                    
                    tax_amount = amount_gross * random.uniform(0.08, 0.15)
                    amount_net = amount_gross - tax_amount
                    
                    status = random.choices(
                        payment_statuses,
                        weights=[3, 7, 75, 12, 3]
                    )[0]
                    
                    payment_date = None
                    if status == "Paid":
                        payment_date = invoice_date + timedelta(days=random.randint(1, 45))
                    
                    invoice = {
                        'invoice_id': f'INV_{invoice_id:06d}',
                        'client_id': project['client_id'],
                        'project_id': project['project_id'],
                        'invoice_type': invoice_type,
                        'invoice_date': invoice_date,
                        'due_date': invoice_date + timedelta(days=30),
                        'amount_gross': int(amount_gross),
                        'tax_amount': int(tax_amount),
                        'amount_net': int(amount_net),
                        'payment_status': status,
                        'payment_date': payment_date,
                        'payment_method': random.choice(payment_methods)
                    }
                    invoices.append(invoice)
                    invoice_id += 1
        
        return pd.DataFrame(invoices)
    
    def create_contracts(self, clients_df: pd.DataFrame) -> pd.DataFrame:
        """Generate realistic contracts"""
        self.log("Generating contracts...")
        
        contract_types = ["Master Service Agreement", "Statement of Work", "Retainer Agreement", "NDA", "Consulting Agreement"]
        renewal_terms = ["Auto-renew", "Manual Renewal", "One-time", "Evergreen"]
        statuses = ["Draft", "Under Review", "Active", "Expired", "Terminated"]
        
        contracts = []
        contract_id = 0
        
        for _, client in clients_df.iterrows():
            # Each client has 1-3 contracts
            num_contracts = random.randint(1, 3)
            
            for i in range(num_contracts):
                contract_type = random.choice(contract_types)
                
                start_date = client['client_since'] + timedelta(days=random.randint(-30, 30))
                contract_duration = random.randint(365, 1095)  # 1-3 years
                end_date = start_date + timedelta(days=contract_duration)
                
                # Contract value correlates with client size
                base_value = client['monthly_retainer'] * 12 * random.uniform(0.5, 2.0)
                contract_value = int(base_value * random.uniform(0.8, 1.5))
                
                # Status based on dates
                if end_date < datetime.now().date():
                    status = random.choice(["Expired", "Terminated"])
                elif start_date > datetime.now().date():
                    status = random.choice(["Draft", "Under Review"])
                else:
                    status = "Active"
                
                contract = {
                    'contract_id': f'CTR_{contract_id:06d}',
                    'client_id': client['client_id'],
                    'contract_type': contract_type,
                    'start_date': start_date,
                    'end_date': end_date,
                    'contract_value': contract_value,
                    'renewal_terms': random.choice(renewal_terms),
                    'status': status
                }
                contracts.append(contract)
                contract_id += 1
        
        return pd.DataFrame(contracts)
    
    def export_datasets(self, datasets: Dict[str, pd.DataFrame]):
        """Export all datasets to CSV"""
        self.log("Exporting datasets...")
        
        total_records = 0
        for name, df in datasets.items():
            filepath = f'{self.output_dir}/{name}.csv'
            df.to_csv(filepath, index=False)
            total_records += len(df)
            self.log(f"Exported {name}: {len(df):,} records -> {filepath}")
        
        self.log(f"Total records exported: {total_records:,}")
        
        # Create a summary file
        summary = {
            'generation_date': datetime.now().isoformat(),
            'total_records': total_records,
            'tables': {name: len(df) for name, df in datasets.items()},
            'target_vps': '194.238.17.65',
            'generator': 'Laika Dynamics CTGAN Enterprise'
        }
        
        import json
        with open(f'{self.output_dir}/dataset_summary.json', 'w') as f:
            json.dump(summary, f, indent=2, default=str)
    
    def validate_datasets(self, datasets: Dict[str, pd.DataFrame]):
        """Validate data quality and relationships"""
        self.log("Validating dataset quality...")
        
        issues = []
        
        # Check for null values in critical columns
        critical_nulls = {
            'clients': ['client_id', 'company_name', 'industry'],
            'projects': ['project_id', 'client_id', 'project_name'],
            'invoices': ['invoice_id', 'client_id', 'amount_gross']
        }
        
        for table, columns in critical_nulls.items():
            if table in datasets:
                df = datasets[table]
                for col in columns:
                    if col in df.columns:
                        null_count = df[col].isnull().sum()
                        if null_count > 0:
                            issues.append(f"{table}.{col}: {null_count} null values")
        
        # Check referential integrity
        if 'clients' in datasets and 'projects' in datasets:
            client_ids = set(datasets['clients']['client_id'])
            project_client_ids = set(datasets['projects']['client_id'])
            orphaned = project_client_ids - client_ids
            if orphaned:
                issues.append(f"Projects with invalid client_ids: {len(orphaned)}")
        
        if issues:
            self.log("Data quality issues found:")
            for issue in issues:
                self.log(f"  - {issue}")
        else:
            self.log("Data quality validation passed!")
        
        # Generate statistics
        self.log("Dataset statistics:")
        for name, df in datasets.items():
            numeric_cols = df.select_dtypes(include=[np.number]).columns
            if len(numeric_cols) > 0:
                self.log(f"  {name}: {len(df):,} rows, {len(df.columns)} columns")

def main():
    """Main execution function"""
    print("🚀 Laika Dynamics Enterprise Data Generator")
    print("=" * 50)
    
    # Check system resources
    memory_gb = psutil.virtual_memory().total / (1024**3)
    print(f"Available RAM: {memory_gb:.1f} GB")
    
    # Optimized for 18GB RAM limit
    if memory_gb < 8:
        print("⚠️  Warning: Less than 8GB RAM detected. Using minimal settings.")
        target_records = 25000
    elif memory_gb >= 18:
        print("✅ Excellent! 18GB+ RAM detected. Using optimized settings.")
        target_records = 120000  # Reduced from 150000 for more conservative approach
    elif memory_gb >= 12:
        print("✅ Good! Sufficient RAM for standard generation.")
        target_records = 75000
    else:
        print("⚠️  Limited RAM. Using reduced settings.")
        target_records = 50000
    
    # Initialize generator
    generator = LaikaDynamicsDataGenerator(target_records=target_records)
    
    # Generate complete dataset
    datasets = generator.generate_complete_dataset()
    
    print("\n" + "=" * 50)
    print("🎉 Data generation completed successfully!")
    print(f"📁 Output directory: {generator.output_dir}")
    print(f"🎯 Ready for upload to VPS: 194.238.17.65")
    print("\nNext steps:")
    print("1. Review generated CSV files")
    print("2. Upload to VPS using: scp data/synthetic/*.csv user@194.238.17.65:~/laika-dynamics-rag/data/synthetic/")
    print("3. Restart RAG system to load new data")

if __name__ == "__main__":
    main()
EOF

    chmod +x scripts/generate_enterprise_data.py
}

# Memory optimization function
optimize_for_memory() {
    log "Optimizing for 18GB RAM usage..."
    
    # Set memory-conscious environment variables
    export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:2048
    export OMP_NUM_THREADS=4
    export MKL_NUM_THREADS=4
    
    # Python memory optimizations
    export PYTHONOPTIMIZE=1
    export PYTHONDONTWRITEBYTECODE=1
}

# Enhanced data generator execution
run_data_generator() {
    log "Starting CTGAN data generation..."
    cd "$PROJECT_DIR"
    source $VENV_NAME/bin/activate
    
    # Apply memory optimizations
    optimize_for_memory
    
    # Run the Python generator with memory monitoring
    python scripts/generate_enterprise_data.py 2>&1 | tee generation.log
    
    if [ $? -eq 0 ]; then
        log "Data generation completed successfully!"
        log "Generated files:"
        ls -la data/synthetic/
    else
        error "Data generation failed. Check generation.log for details."
    fi
}

# Create deployment package
create_deployment_package() {
    log "Creating deployment package..."
    cd "$PROJECT_DIR"
    
    # Create a compressed archive
    tar -czf laika-dynamics-synthetic-data.tar.gz data/synthetic/
    
    log "Deployment package created: laika-dynamics-synthetic-data.tar.gz"
    log "Size: $(du -h laika-dynamics-synthetic-data.tar.gz | cut -f1)"
}

# Upload to VPS function
upload_to_vps() {
    log "Preparing VPS upload instructions..."
    
    cat > upload_instructions.txt << 'EOF'
# Laika Dynamics Data Upload Instructions

## Upload synthetic data to VPS:
scp laika-dynamics-synthetic-data.tar.gz user@194.238.17.65:~/

## On VPS, extract and organize:
ssh user@194.238.17.65
cd ~/
tar -xzf laika-dynamics-synthetic-data.tar.gz
mkdir -p ~/laika-dynamics-rag/data/
mv data/synthetic ~/laika-dynamics-rag/data/

## Restart RAG services:
cd ~/laika-dynamics-rag/
docker-compose restart
# or
systemctl restart laika-rag-service

## Verify data load:
ls -la ~/laika-dynamics-rag/data/synthetic/
EOF
    
    log "Upload instructions created: upload_instructions.txt"
}

# Performance monitoring
monitor_performance() {
    log "System performance monitoring during generation..."
    
    cat > scripts/monitor_resources.py << 'EOF'
#!/usr/bin/env python3
import psutil
import time
import json
from datetime import datetime

def monitor_resources(duration_minutes=30):
    """Monitor system resources during data generation"""
    print("Starting resource monitoring...")
    
    stats = []
    start_time = time.time()
    end_time = start_time + (duration_minutes * 60)
    
    while time.time() < end_time:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        stat = {
            'timestamp': datetime.now().isoformat(),
            'cpu_percent': cpu_percent,
            'memory_percent': memory.percent,
            'memory_available_gb': memory.available / (1024**3),
            'disk_free_gb': disk.free / (1024**3)
        }
        stats.append(stat)
        
        print(f"CPU: {cpu_percent:5.1f}% | RAM: {memory.percent:5.1f}% | Available: {memory.available/(1024**3):5.1f}GB")
        
        if memory.percent > 85:
            print("⚠️  High memory usage detected!")
        
        time.sleep(30)  # Check every 30 seconds
    
    # Save monitoring results
    with open('../monitoring_results.json', 'w') as f:
        json.dump(stats, f, indent=2)
    
    print("Resource monitoring completed.")

if __name__ == "__main__":
    monitor_resources()
EOF
    
    chmod +x scripts/monitor_resources.py
}

# Main execution flow
main() {
    log "🚀 Laika Dynamics CTGAN Data Generator - 18GB RAM Optimized"
    log "Starting comprehensive data generation pipeline..."
    
    # Phase 1: System preparation
    log "=== Phase 1: System Preparation ==="
    check_system
    cleanup_system  # Clean up before starting
    setup_project
    setup_python_env
    
    # Phase 2: Schema and generator creation
    log "=== Phase 2: Schema & Generator Setup ==="
    create_schemas
    create_ctgan_generator
    monitor_performance
    
    # Phase 3: Data generation
    log "=== Phase 3: Data Generation ==="
    run_data_generator
    
    # Phase 4: Packaging and deployment prep
    log "=== Phase 4: Packaging & Deployment ==="
    create_deployment_package
    upload_to_vps
    
    # Final cleanup
    log "=== Phase 5: Cleanup ==="
    cleanup_system
    
    log "🎉 All phases completed successfully!"
    log "📁 Project directory: $PROJECT_DIR"
    log "📦 Deployment package: $PROJECT_DIR/laika-dynamics-synthetic-data.tar.gz"
    log "📋 Upload instructions: $PROJECT_DIR/upload_instructions.txt"
    
    # Final disk space check
    FINAL_DISK_FREE=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    log "Final disk space available: ${FINAL_DISK_FREE}GB"
    
    echo ""
    echo "==============================================="
    echo "🎯 SUMMARY"
    echo "==============================================="
    echo "✅ CTGAN environment configured for 18GB RAM"
    echo "✅ Synthetic data generation completed"
    echo "✅ Deployment package created"
    echo "✅ VPS upload instructions ready"
    echo "✅ System cleanup completed"
    echo ""
    echo "Next steps:"
    echo "1. cd $PROJECT_DIR"
    echo "2. Follow instructions in upload_instructions.txt"
    echo "3. Monitor VPS RAG system integration"
    echo "==============================================="
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF