# Specify the required Terraform version
terraform {
  required_version = ">= 1.5, < 2.0"
}

# Define the AWS provider and region
provider "aws" {
  region = "us-east-1"
}

# Define the Vault provider to access secrets
provider "vault" {
  address = "http://127.0.0.1:8200" # Replace with your Vault server address
  token   = "hvs.CAESIOhvuMV82yDIiUJKkotlZWl5MzC91bOaLBZxNiZ-MGBkGh4KHGh2cy50ZzhuUkFJTWRoVm9lbEV4SURRRnZtdXg"        # Replace with a valid Vault token
}

# Retrieve AWS access keys from Vault
data "vault_generic_secret" "aws_creds" {
  path = "secret/aws-creds" # Path to your secret in Vault
}

# Use AWS access keys from Vault in your AWS provider configuration
provider "aws" {
  access_key = data.vault_generic_secret.aws_creds.data["access_key"]
  secret_key = data.vault_generic_secret.aws_creds.data["secret_key"]
}

# Define your EC2 instances
resource "aws_instance" "ec2_instance" {
  count         = 3
  ami           = "ami-0e768c81329b19ea3"
  instance_type = "t2.micro"
  key_name      = "tc-gateway"
  vpc_security_group_ids = ["sg-0789a5798fedfd89c"]
  subnet_id     = "subnet-0492cfdf22874a501"
  associate_public_ip_address = true

  # User data script
  user_data = <<-EOF
    <powershell>
      # Use IAM role for AWS access, no need to specify credentials

      # Install additional software (e.g., 7-Zip)
      choco install 7zip -y

      # Add firewall rules using PowerShell
      # Example: Allow inbound traffic on port 80 (HTTP)
      New-NetFirewallRule -Name Allow-HTTP-Inbound -Enabled True -Direction Inbound -Protocol TCP -Action Allow -Profile Any -LocalPort 80

      # Perform other Windows configurations and installations here

      # For example, Windows updates, additional software installations, and more.

    </powershell>
  EOF

  # Use count.index to generate unique instance names
  tags = {
    Name = "tc-instance-${count.index + 1}"
  }
}

# Define an IAM role for EC2 instances
resource "aws_iam_role" "ec2_instance_role" {
  name = "EC2InstanceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach a policy to the IAM role with necessary permissions
resource "aws_iam_policy" "ec2_instance_policy" {
  name = "EC2InstancePolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          # Add other permissions as needed
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "ec2_instance_policy_attachment" {
  policy_arn = aws_iam_policy.ec2_instance_policy.arn
  role       = aws_iam_role.ec2_instance_role.name
}