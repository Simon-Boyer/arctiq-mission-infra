# Arctiq Mission Infrastructure
Mission for Arctiq interview process

## Requirements
1. Valid gcloud account with project configured, connected via gcloud cli on current machine
2. Cloudflare account with your dns domain
3. Terraform installed

## Deployment process:

1. `gcloud auth application-default login`
2. `export CLOUDFLARE_API_KEY=your_cloudflare_key && export CLOUDFLARE_EMAIL=your_cloudflare_email`
3. `cd terraform/stage1 && terraform init && terraform apply`
4. `cd ../stage2 && terraform init && terraform apply`
