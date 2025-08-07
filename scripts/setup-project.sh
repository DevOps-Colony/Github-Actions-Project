#!/usr/bin/env bash
# scripts/setup-project.sh
#
# One-time bootstrap helper for the Bank-App CI/CD demo.
# ───────────────────────────────────────────────────────

set -euo pipefail

# ────── coloured output helpers ──────────────────────────────────────────────
RED=$'\e[0;31m'; GREEN=$'\e[0;32m'; YELLOW=$'\e[1;33m'; BLUE=$'\e[0;34m'; NC=$'\e[0m'

status()   { printf '%s\n' "${GREEN}✅ $*${NC}"; }
warning()  { printf '%s\n' "${YELLOW}⚠️  $*${NC}"; }
error()    { printf '%s\n' "${RED}❌ $*${NC}"; }
info()     { printf '%s\n' "${BLUE}ℹ️  $*${NC}"; }

# ────── prerequisite checks ─────────────────────────────────────────────────
check_prerequisites() {
  info "Checking prerequisites …"

  # ─ AWS CLI ───────────────────────────────────────────────────────────────
  if ! command -v aws &>/dev/null; then
    error "AWS CLI is not installed (command 'aws' not found)."
    echo "Install with either:"
    echo "  sudo apt install awscli      # quick but older version"
    echo "  or"
    echo "  curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o aws.zip"
    echo "  unzip aws.zip && sudo ./aws/install"
    exit 1
  fi
  status "AWS CLI found: $(command -v aws)"

  # ─ AWS credentials ───────────────────────────────────────────────────────
  if ! aws sts get-caller-identity &>/dev/null; then
    error "AWS CLI is not configured – run 'aws configure' first."
    exit 1
  fi
  status "AWS CLI is configured (credentials valid)"

  # ─ Terraform (optional locally) ───────────────────────────────────────────
  if command -v terraform &>/dev/null; then
    status "Terraform found: $(terraform version -json | jq -r .terraform_version)"
  else
    warning "Terraform not found – local plans will be skipped (CI uses its own)."
  fi

  # ─ Docker (optional locally) ──────────────────────────────────────────────
  command -v docker &>/dev/null \
    && status "Docker found: $(docker --version | cut -d',' -f1)" \
    || warning "Docker not found – local image builds will be skipped."

  # ─ kubectl (optional locally) ────────────────────────────────────────────
  command -v kubectl &>/dev/null \
    && status "kubectl found: $(kubectl version --client --short)" \
    || warning "kubectl not found – local cluster ops will be skipped."
}

# ────── terraform.tfvars tweaker ────────────────────────────────────────────
update_terraform_config() {
  info "Updating infra/terraform.tfvars with a unique S3 bucket suffix …"
  local tfvars="infra/terraform.tfvars"
  [[ -f $tfvars ]] || { error "$tfvars not found"; exit 1; }

  local suffix
  suffix=$(date +%s | tail -c 6)
  sed -i.bak -E \
    "s/(terraform_state_bucket *= *\"bankapp-terraform-state-bucket-)[0-9]{6}(\")/\\1${suffix}\\2/" \
    "$tfvars"

  status "S3 bucket suffix set to ${suffix}"
}

# ────── SonarCloud hint ─────────────────────────────────────────────────────
update_sonar_config() {
  info "Update 'sonar-project.properties' with your own values:"
  echo "  • sonar.projectKey        =  <your-github-username>_bankapp"
  echo "  • sonar.organization      =  <your-sonar-org>"
  read -rp "Press ENTER once you have done this … "
}

# ────── backend template helper ─────────────────────────────────────────────
setup_terraform_backend() {
  info "Ensuring infra/backend.tf.enabled template exists …"
  local backend="infra/backend.tf.enabled"
  [[ -f $backend ]] && { status "Template already present"; return; }

  cat >"$backend" <<'EOF'
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
  status "Created $backend"
}

# ────── GitHub Secrets reminder ─────────────────────────────────────────────
display_github_secrets() {
  info "GitHub Secrets to add:"
  cat <<'EOF'
  Repository → Settings → Secrets → Actions
  -----------------------------------------
  • AWS_ACCESS_KEY_ID
  • AWS_SECRET_ACCESS_KEY
  • AWS_REGION              (e.g. us-west-2)
  • SONAR_TOKEN             (from SonarCloud ⚙ → My Account → Security)
EOF
}

# ────── next-steps summary ──────────────────────────────────────────────────
next_steps() {
  info "Next steps"
  cat <<'EOF'
  1. Commit & push all changes to the main branch.
  2. GitHub Actions will then:
     • Build & scan Docker images
     • Provision S3 + DynamoDB for Terraform state
     • Deploy VPC, EKS, RDS, ALB via Terraform
     • Install ALB ingress controller
     • Roll out your application via Helm
  3. Watch the workflow; the Load Balancer DNS appears in the logs.
  4. First run can take 15-20 min.
EOF
  status "Bootstrap script completed 🎉"
}

# ────── main ────────────────────────────────────────────────────────────────
main() {
  echo -e "\n🚀 Setting up Bank Application CI/CD Pipeline"
  echo    "============================================"

  check_prerequisites
  update_terraform_config
  update_sonar_config
  setup_terraform_backend
  display_github_secrets
  next_steps
}

main "$@"

