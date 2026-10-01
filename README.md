# CloudCart — Infrastructure as Code (Terraform)
### Om Pawar — B.Sc Cloud Computing, Field Project Step 3

This folder contains Terraform code that automatically creates the entire
AWS architecture (VPC, Subnets, Security Groups, EC2 Auto Scaling Group,
Application Load Balancer, RDS MySQL, S3, IAM Role, CloudWatch) — the same
architecture that was manually built in Step 2, now defined as code.

---

## 1. Install Terraform (on your laptop)

- Download from https://developer.hashicorp.com/terraform/downloads
- Verify install: `terraform -version`

## 2. Install & Configure AWS CLI

- Download AWS CLI, then run:
```
aws configure
```
- Enter your AWS Access Key, Secret Key, Region (`ap-south-1`), output format (`json`)
  (Access Key/Secret Key: IAM → Users → Security credentials → Create access key)

## 3. Create an EC2 Key Pair (one-time, via console)
EC2 Console → Key Pairs → Create key pair → name it `myapp-key` (matches `variables.tf`)

## 4. Upload website files to a placeholder S3 path
Before running Terraform, decide your bucket name in `variables.tf`
(`s3_bucket_name`) — must be globally unique. After `terraform apply` creates
the bucket, upload your `index.php`, `style.css`, `script.js` into a
`cloudcart/` folder inside it (Console or `aws s3 cp` — see below).

## 5. Run Terraform

```bash
cd terraform-cloudcart
terraform init      # downloads AWS provider
terraform plan       # shows what will be created (review this)
terraform apply       # type 'yes' to confirm — creates everything (~10-15 min, RDS takes longest)
```

## 6. Upload website files to S3 (after bucket exists)

```bash
aws s3 cp index.php  s3://<your-bucket-name>/cloudcart/
aws s3 cp style.css  s3://<your-bucket-name>/cloudcart/
aws s3 cp script.js  s3://<your-bucket-name>/cloudcart/
```

## 7. Update index.php with the real RDS endpoint

```bash
terraform output rds_endpoint
```
Copy that value into `index.php`'s `$servername`, then re-upload it to S3
(same command as above), then refresh instances:
```bash
aws autoscaling start-instance-refresh --auto-scaling-group-name MyApp-ASG
```

## 8. Get your live website URL

```bash
terraform output alb_dns_name
```
Open that URL in a browser — your CloudCart site should load.

## 9. Destroy everything after submission (avoid billing)

```bash
terraform destroy
```
Type `yes` to confirm. This deletes every resource Terraform created.

---

## Submission Checklist (as per teacher's requirements)

- [ ] **IaC Code** — this whole folder (`.tf` files), pushed to GitHub
- [ ] **Architecture Diagram** — the diagram from your original project PDF
- [ ] **Cloud Resource Screenshots** — after `terraform apply`, screenshot: VPC, Subnets, EC2 instances, Load Balancer, Auto Scaling Group, RDS, S3, CloudWatch dashboard (all in AWS Console)
- [ ] **GitHub Repository** — create a repo, push this folder (see below)
- [ ] **Brief Documentation** — 1-2 pages: what each `.tf` file does, screenshots of `terraform apply` running successfully, screenshot of live website working

## Pushing to GitHub

```bash
cd terraform-cloudcart
git init
git add .
git commit -m "Step 3: Infrastructure as Code (Terraform) - CloudCart AWS deployment"
git branch -M main
git remote add origin https://github.com/<your-username>/cloudcart-aws-iac.git
git push -u origin main
```

**Important:** never commit real passwords. Before pushing, either:
- remove the default password from `variables.tf` and instead create a
  `terraform.tfvars` file (add it to `.gitignore`) with your real password, or
- leave the placeholder default as-is in the code you submit (acceptable for
  an academic project, but mention in your documentation that it should be
  a secret in a real production setup)

Add a `.gitignore` with:
```
.terraform/
*.tfstate
*.tfstate.backup
terraform.tfvars
```
