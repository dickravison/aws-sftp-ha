# HA SFTP in AWS
This will create an EC2 ASG behind an NLB and syncs uploads from each of the SFTP user's upload directory into S3. This will allow users to auth with both SSH keys and passwords. You can only access the backend EC2 instances using SSM, there is no direct SSH access other than SFTP.

DDoS protection is provided automatically by AWS Shield Standard as this is applied to NLBs.

The CIDR range for the VPC is decided by what 'stage' is defined in the Stage variable. A local mapping in the `vpc.tf` file is then used to determine what CIDR range is used in the VPC and then the corresponding public and private subnets.

```
  cidr_range = {
    latest = "10.1.0.0/16"
    test   = "10.2.0.0/16"
    beta   = "10.3.0.0/16"
    prod   = "10.4.0.0/16"
  }
  public_range = {
    latest = "10.1.1.0/20"
    test   = "10.2.1.0/20"
    beta   = "10.3.1.0/20"
    prod   = "10.4.1.0/20"
  }
  private_range = {
    latest = "10.1.16.0/20"
    test   = "10.2.16.0/20"
    beta   = "10.3.16.0/20"
    prod   = "10.4.16.0/20"
  }
```

These ranges aren't split in a way that I would recommend but for the purposes of this example, these will do. The allocation should be skewed more towards the private range as there should be minimal IP requirements for the public range but this would also be dependent on what other resources are deployed in the same environment. I'd probably look at changing these to a /20 for public and a /18 for private as a good starting point. The `cidrsubnet()` function would need to be updated for the private subnets, an example would be to change the below for the 'latest' stage:

```
...
private_range = {
  latest = "10.1.64.0/18"
...

resource "aws_subnet" "private" {
...
  cidr_block        = cidrsubnet(lookup(local.private_range, var.Stage), 2, count.index)
...
}
```

which with 3 AZ's would then give you 251 available IPs in each public subnet, and 4091 available IPs in each private subnet.

DNS records pointing to the NLB will be created using an existing zone which is passed in as a var. The hostname var should be set to the same domain name as the zone. The zone was originally created within this but it would create duplicated zones when multiple environments were deployed.

User management is handled by DynamoDB. A script is ran every minute to ensure any new users are added and update existing users passwords and/or keyfiles too. A user will need to be added as a new item in the DynamoDB table and an example is below for a user with both a password and keyfile. A user can have a password, a keyfile or both. The UserName attribute is the only required field.

| UserName   | Password           | Keyfile                                                            |
|------------|--------------------|--------------------------------------------------------------------|
| test-sftp1 | asfgafsgasfdgasfga | ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIdf2wyWxzYm+C++JP2B8gzE/1UrV2d |

First, the S3 backend needs to be configured. To do this I have the bucket, key, and region configured in `backend.conf`.

```
$ cat backend.conf
bucket = "example-remote-s3-state"
key    = "tf.state"
region = "eu-west-1"
```

and then specify this file when running `terraform init`.

```
terraform init --backend-config=backend.conf
```

This should allow you to deploy multiple environments in the same account by using separate tfvars files and Terraform Workspaces. Terraform Workspaces basically creates separate state files in the same backend. For example:

```
$ terraform workspace new test
Created and switched to workspace "test"!

You're now on a new, empty workspace. Workspaces isolate their state,
so if you run "terraform plan" Terraform will not see any existing state
for this configuration.
$ terraform workspace new beta
Created and switched to workspace "beta"!

You're now on a new, empty workspace. Workspaces isolate their state,
so if you run "terraform plan" Terraform will not see any existing state
for this configuration.
```

You should then be in the workspace that you most recently created, you can check this with

```
$ terraform workspace list
  default
* beta
  test
```

and then switch between workspaces using this example

```
$ terraform workspace list
  default
* beta
  test

$ terraform workspace select test
Switched to workspace "test".
$ terraform workspace list
  default
  beta
* test
```

You can then specify the tfvars when running `terraform plan` and `terraform apply` while in each workspace and this will deploy separate environments within the same account using the same codebase.

```
$ terraform workspace select beta
...
$ terraform plan -var-file=beta.tfvars
...
$ terraform apply -var-file=beta.tfvars
...
$ terraform workspace select test
...
$ terraform plan -var-file=test.tfvars
...
$ terraform apply -var-file=test.tfvars
...
```

Once this has finished, the below commands show the two NLBs created and both with tags showing the different environments they belong to.

```
$ aws elbv2 describe-load-balancers --query LoadBalancers[].DNSName
[
    "sftp-dvsn-beta-nlb-2ffeb26ee76dfb0a.elb.eu-west-1.amazonaws.com",
    "sftp-dvsn-test-nlb-b9621062eedf4158.elb.eu-west-1.amazonaws.com"
]

$ aws elbv2 describe-tags --resource-arns `aws elbv2 describe-load-balancers --query LoadBalancers[].LoadBalancerArn --output
text` --query TagDescriptions[].Tags
[
    [
        {
            "Key": "Project Name",
            "Value": "sftp-dvsn"
        },
        {
            "Key": "Hostname",
            "Value": "sftp.dvsn.io"
        },
        {
            "Key": "Environment",
            "Value": "beta"
        },
        {
            "Key": "Creator",
            "Value": "Rick Davison"
        }
    ],
    [
        {
            "Key": "Project Name",
            "Value": "sftp-dvsn"
        },
        {
            "Key": "Hostname",
            "Value": "sftp.dvsn.io"
        },
        {
            "Key": "Environment",
            "Value": "test"
        },
        {
            "Key": "Creator",
            "Value": "Rick Davison"
        }
    ]
]
```

and then now to test it actually works. Testing SFTP to both test and beta environments. The users created manually outside of this in DynamoDB are:

- test-sftp1 - password only
- test-sftp2 - key only
- beta-sftp1 - password only
- beta-sftp2 - key only
```
$ sftp test-sftp1@sftp-dvsn-test-nlb-b9621062eedf4158.elb.eu-west-1.amazonaws.com
The authenticity of host 'sftp-dvsn-test-nlb-b9621062eedf4158.elb.eu-west-1.amazonaws.com (52.51.173.32)' can't be established.
ECDSA key fingerprint is SHA256:1pRz0v2M0Di4jBy5ZqK7Drj6BSUg70mLs1H3HN9JWv8.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'sftp-dvsn-test-nlb-b9621062eedf4158.elb.eu-west-1.amazonaws.com,52.51.173.32' (ECDSA) to the list of known hosts.
test-sftp1@sftp-dvsn-test-nlb-b9621062eedf4158.elb.eu-west-1.amazonaws.com's password:
Connected to test-sftp1@sftp-dvsn-test-nlb-b9621062eedf4158.elb.eu-west-1.amazonaws.com.
sftp>

$ sftp test-sftp2@sftp-dvsn-test-nlb-b9621062eedf4158.elb.eu-west-1.amazonaws.com
Connected to test-sftp2@sftp-dvsn-test-nlb-b9621062eedf4158.elb.eu-west-1.amazonaws.com.
sftp>

$ sftp beta-sftp1@sftp-dvsn-beta-nlb-2ffeb26ee76dfb0a.elb.eu-west-1.amazonaws.com
The authenticity of host 'sftp-dvsn-beta-nlb-2ffeb26ee76dfb0a.elb.eu-west-1.amazonaws.com (54.78.179.192)' can't be established.
ECDSA key fingerprint is SHA256:L947f9FtC9h7VTlBaI5NSExt6I3dU9rfGXBmDbGThZY.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'sftp-dvsn-beta-nlb-2ffeb26ee76dfb0a.elb.eu-west-1.amazonaws.com,54.78.179.192' (ECDSA) to the list of known hosts.
beta-sftp1@sftp-dvsn-beta-nlb-2ffeb26ee76dfb0a.elb.eu-west-1.amazonaws.com's password:
Connected to beta-sftp1@sftp-dvsn-beta-nlb-2ffeb26ee76dfb0a.elb.eu-west-1.amazonaws.com.
sftp>
$ sftp beta-sftp2@sftp-dvsn-beta-nlb-2ffeb26ee76dfb0a.elb.eu-west-1.amazonaws.com
Connected to beta-sftp2@sftp-dvsn-beta-nlb-2ffeb26ee76dfb0a.elb.eu-west-1.amazonaws.com.
sftp>
```

# Improvements
- Use Route53 data source to check if route53 zone exists for hostname var and use this instead of the existing zone ID var, if it doesn't then create a route53 zone
- Replace VPC and subnet creation so that it's dynamically created rather than static ranges
- Replace resources with modules
- Replace storage so that transfer is bidirectional, maybe EFS.
- Create hosted zone through TF or dynamically look up the zone ID of a given hostname
- Delete users that aren't present in DynamoDB.
- Flesh the README out more
