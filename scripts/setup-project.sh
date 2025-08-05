#!/bin/bash
# scripts/setup-project.sh

set -e

echo "🚀 Setting up Bank Application CI/CD Pipeline"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if required tools are installed
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        echo "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi
    print_status "AWS CLI is installed"
    
    # Check if AWS is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    print_status "AWS CLI is configured"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform is not installed locally (optional for local testing)"
    else
        print_status "Terraform is installed"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed locally (optional for local testing)"
    else
        print_status "Docker is installed"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed locally (optional for local testing)"
    else
        print_status "kubectl is installed"
    fi
}

# Update terraform.tfvars with unique values
update_terraform_config() {
    echo ""
    print_info "Updating Terraform configuration..."
    
    # Generate unique suffix for S3 bucket
    RANDOM_SUFFIX=$(date +%s | tail -c 6)
    
    # Update terraform.tfvars
    if [ -f "infra/terraform.tfvars" ]; then
        sed -i.bak "s/terraform_state_bucket = \"bankapp-terraform-state-bucket-2024\"/terraform_state_bucket = \"bankapp-terraform-state-bucket-${RANDOM_SUFFIX}\"/" infra/terraform.tfvars
        print_status "Updated S3 bucket name with unique suffix: ${RANDOM_SUFFIX}"
    else
        print_error "terraform.tfvars not found in infra/ directory"
        exit 1
    fi
}

# Update SonarCloud configuration
update_sonar_config() {
    echo ""
    print_info "Updating SonarCloud configuration..."
    
    echo "Please update the following in sonar-project.properties:"
    echo "1. sonar.projectKey=your-github-username_bankapp"
    echo "2. sonar.organization=your-sonarcloud-org"
    echo ""
    echo "These values should match your SonarCloud project settings."
    
    read -p "Press Enter to continue after updating sonar-project.properties..."
}

# Display GitHub Secrets that need to be configured
display_github_secrets() {
    echo ""
    print_info "GitHub Secrets Configuration"
    echo "==========================================="
    echo "Please add the following secrets to your GitHub repository:"
    echo "(Go to: Settings > Secrets and variables > Actions)"
    echo ""
    echo "Required Secrets:"
    echo "- AWS_ACCESS_KEY_ID: Your AWS Access Key ID"
    echo "- AWS_SECRET_ACCESS_KEY: Your AWS Secret Access Key"
    echo "- AWS_REGION: us-west-2 (or your preferred region)"
    echo "- SONAR_TOKEN: Your SonarCloud token"
    echo ""
    echo "How to get SonarCloud token:"
    echo "1. Go to https://sonarcloud.io"
    echo "2. Log in with your GitHub account"
    echo "3. Go to My Account > Security"
    echo "4. Generate new token"
    echo "5. Copy the token to GitHub Secrets"
}

# Create initial backend configuration
setup_terraform_backend() {
    echo ""
    print_info "Setting up Terraform backend configuration..."
    
    if [ -f "infra/backend.tf.enabled" ]; then
        print_status "Backend configuration template already exists"
    else
        print_warning "Creating backend.tf.enabled template..."
        cat > infra/backend.tf.enabled << EOF
terraform {
  backend "s3" {
    bucket         = "BUCKET_NAME_PLACEHOLDER"
    key            = "terraform/infrastructure.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
EOF
        print_status "Created backend.tf.enabled template"
    fi
}

# Display next steps
display_next_steps() {
    echo ""
    print_info "Next Steps"
    echo "=========="
    echo "1. 🔧 Configure GitHub Secrets (see above)"
    echo "2. 🏗️  Push your code to GitHub main branch"
    echo "3. 🚀 GitHub Actions will automatically:"
    echo "   - Create S3 bucket and DynamoDB table"
    echo "   - Deploy AWS infrastructure (VPC, EKS, RDS, ALB)"
    echo "   - Run security scans (SonarCloud, Trivy)"
    echo "   - Build and deploy your application"
    echo ""
    echo "4. 🌐 Access your application at the Load Balancer URL"
    echo "   (URL will be displayed in GitHub Actions output)"
    echo ""
    print_warning "Note: Initial deployment may take 15-20 minutes"
    echo ""
    print_status "Setup completed! 🎉"
}

# Main execution
main() {
    check_prerequisites
    update_terraform_config
    update_sonar_config
    setup_terraform_backend
    display_github_secrets
    display_next_steps
}

# Run main function
main