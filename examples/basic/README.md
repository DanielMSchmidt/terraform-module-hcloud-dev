# Basic Example

This example creates one Go-focused development server in Hetzner Cloud.

## Prerequisites

- Terraform installed locally
- Hetzner Cloud API token
- Local provider build at `/Users/danielschmidt/work/terraform-provider-hcloud`

## Steps

1. Create Terraform CLI config for provider override:

   ```bash
   cp terraform.dev.tfrc.example terraform.dev.tfrc
   ```

2. Create variable file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` and set your token.

4. Run Terraform:

   ```bash
   TF_CLI_CONFIG_FILE=$(pwd)/terraform.dev.tfrc terraform init
   TF_CLI_CONFIG_FILE=$(pwd)/terraform.dev.tfrc terraform apply
   ```

5. Connect:

   ```bash
   terraform output -raw ssh_command
   ```
