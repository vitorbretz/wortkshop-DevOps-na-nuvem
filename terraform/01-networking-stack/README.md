# 01-networking-stack

VPC Network Infrastructure implementation following **ADR-001: AWS VPC Network Architecture**.

## Architecture Overview

This Terraform stack creates a complete AWS VPC networking infrastructure with:

- **VPC**: CIDR `10.0.0.0/24` (254 usable IPs)
- **Public Subnets**: 2 subnets across 2 AZs
  - `10.0.0.0/26` (us-east-1a) - 62 usable IPs
  - `10.0.0.64/26` (us-east-1b) - 62 usable IPs
- **Private Subnets**: 2 subnets across 2 AZs
  - `10.0.0.128/26` (us-east-1a) - 62 usable IPs
  - `10.0.0.192/26` (us-east-1b) - 62 usable IPs
- **Internet Gateway**: For public subnet connectivity
- **NAT Gateway**: Single NAT in us-east-1a for private subnet egress
- **Route Tables**: Separate for public and private subnets

## File Structure

```
01-networking-stack/
├── provider.tf                    # AWS provider configuration
├── versions.tf                    # Terraform and provider versions
├── variables.tf                   # Input variables
├── outputs.tf                     # Output values
├── vpc.tf                         # VPC resource
├── vpc-public-subnets.tf          # Public subnets
├── vpc-private-subnets.tf         # Private subnets
├── vpc-internet-gateway.tf        # Internet Gateway
├── vpc-nat-gateway.tf             # NAT Gateway + Elastic IP
├── vpc-public-route-table.tf      # Public route table
├── vpc-private-route-table.tf     # Private route table
├── terraform.tfvars.example       # Example variable values
└── README.md                      # This file
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create VPC resources

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform/01-networking-stack
terraform init
```

### 2. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Validate Configuration

```bash
terraform fmt -recursive
terraform validate
```

### 4. Plan Infrastructure

```bash
terraform plan
```

### 5. Apply Infrastructure

```bash
terraform apply
```

## Configuration

### Required Variables

All variables have sensible defaults as per ADR-001. Customize in `terraform.tfvars` if needed:

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `project_name` | Project name for resource naming | `dvn-workshop` |
| `environment` | Environment (dev/staging/prod) | `dev` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/24` |
| `availability_zones` | List of AZs | `["us-east-1a", "us-east-1b"]` |
| `public_subnet_cidrs` | Public subnet CIDRs | `["10.0.0.0/26", "10.0.0.64/26"]` |
| `private_subnet_cidrs` | Private subnet CIDRs | `["10.0.0.128/26", "10.0.0.192/26"]` |
| `create_nat_gateway` | Create NAT Gateway | `true` |

### Outputs

After successful apply, you'll have access to:

- `vpc_id` - VPC ID
- `public_subnet_ids` - List of public subnet IDs
- `private_subnet_ids` - List of private subnet IDs
- `nat_gateway_public_ip` - NAT Gateway public IP
- `internet_gateway_id` - Internet Gateway ID
- And more... (see outputs.tf)

## Cost Estimation

**Monthly costs (us-east-1):**

| Resource | Cost |
|----------|------|
| VPC | Free |
| Subnets | Free |
| Internet Gateway | Free (data transfer charges apply) |
| NAT Gateway | ~$32.85/month (730 hours × $0.045/hour) |
| Elastic IP | Free (while attached) |
| **Total Base Cost** | **~$35-50/month** |

*Note: Data transfer costs not included (~$0.09/GB out to internet, ~$0.01/GB cross-AZ)*

## Important Notes

### NAT Gateway - Single Point of Failure

⚠️ **This configuration uses a single NAT Gateway in us-east-1a for cost optimization.**

**Implications:**
- ✅ Cost savings: ~50% cheaper than 2 NAT Gateways
- ⚠️ If us-east-1a fails, private subnets lose internet access
- ⚠️ Cross-AZ data transfer charges apply

**For Production:**
Consider upgrading to 2 NAT Gateways (one per AZ) for high availability.

## Validation & Testing

### Format Code
```bash
terraform fmt -recursive
```

### Validate Syntax
```bash
terraform validate
```

### Security Scan (optional)
```bash
# Install tfsec: https://github.com/aquasecurity/tfsec
tfsec .

# Or use checkov: https://github.com/bridgecrewio/checkov
checkov -d .
```

### Plan Review
```bash
terraform plan -out=tfplan
terraform show tfplan
```

## Operational Procedures

### View Current State
```bash
terraform show
```

### List Resources
```bash
terraform state list
```

### Get Specific Output
```bash
terraform output vpc_id
terraform output -json public_subnet_ids
```

### Update Infrastructure
```bash
terraform plan
terraform apply
```

### Destroy Infrastructure
```bash
terraform destroy
```

## Troubleshooting

### Issue: "Error creating VPC"
- Check AWS credentials are configured
- Verify IAM permissions for VPC creation
- Ensure region supports requested AZs

### Issue: "Error creating NAT Gateway"
- Ensure Internet Gateway is created first (handled by depends_on)
- Verify Elastic IP quota in your account
- Check if public subnet exists

### Issue: "Error creating Subnet: InvalidSubnet.Conflict"
- CIDR blocks may overlap with existing resources
- Verify CIDR blocks don't conflict in your AWS account

## Monitoring

### CloudWatch Metrics

Monitor NAT Gateway:
- `BytesOutToDestination` - Outbound traffic
- `ActiveConnectionCount` - Active connections
- `ErrorPortAllocation` - Port allocation errors

### Recommended Alarms

```bash
# High data transfer (cost alert)
aws cloudwatch put-metric-alarm \
  --alarm-name nat-high-data-transfer \
  --metric-name BytesOutToDestination \
  --namespace AWS/NATGateway \
  --statistic Sum \
  --period 86400 \
  --threshold 100000000000 \
  --comparison-operator GreaterThanThreshold
```

## Disaster Recovery

### Backup State
```bash
# Remote state recommended for production
# Configure S3 backend in versions.tf
```

### Emergency: Recreate NAT Gateway
If us-east-1a fails, manually create NAT in us-east-1b:

```bash
# Get public subnet ID in us-east-1b
terraform output public_subnet_ids

# Emergency manual creation
aws ec2 allocate-address --domain vpc
aws ec2 create-nat-gateway \
  --subnet-id <subnet-id-from-output> \
  --allocation-id <eip-allocation-id>

# Update route table
aws ec2 replace-route \
  --route-table-id <private-rt-id> \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <new-nat-id>
```

## References

- **ADR-001**: `docs/architecture/ADR-001-vpc-network-architecture.md`
- **Naming Conventions**: `docs/standards/terraform-naming-conventions.md`
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues or questions:
1. Review ADR-001 for architectural decisions
2. Check Terraform plan output for errors
3. Review AWS CloudWatch logs
4. Contact DevOps team

---

**Last Updated**: 2026-07-25  
**ADR Reference**: ADR-001  
**Maintained By**: DevOps Team
