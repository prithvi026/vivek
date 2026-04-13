# IAM POLICY REQUIREMENTS FOR EKS CLUSTER

## OVERVIEW
To create and manage EKS cluster with storage drivers, you need specific IAM permissions.

---

## OPTION 1: COMPREHENSIVE POLICY (RECOMMENDED FOR TESTING)

### Full Policy JSON

Save this as: `eks-full-access-policy.json`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EKSClusterManagement",
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EC2FullAccess",
            "Effect": "Allow",
            "Action": [
                "ec2:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "IAMManagement",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:PassRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:GetInstanceProfile",
                "iam:ListInstanceProfilesForRole",
                "iam:CreateServiceLinkedRole",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:GetRolePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:ListRolePolicies",
                "iam:TagRole",
                "iam:UntagRole"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CloudFormationAccess",
            "Effect": "Allow",
            "Action": [
                "cloudformation:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AutoScalingAccess",
            "Effect": "Allow",
            "Action": [
                "autoscaling:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EBSStorageAccess",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateVolume",
                "ec2:DeleteVolume",
                "ec2:AttachVolume",
                "ec2:DetachVolume",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumeAttribute",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:ModifyVolume",
                "ec2:DescribeAvailabilityZones"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EFSStorageAccess",
            "Effect": "Allow",
            "Action": [
                "elasticfilesystem:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "FSxStorageAccess",
            "Effect": "Allow",
            "Action": [
                "fsx:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CloudWatchAccess",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        },
        {
            "Sid": "KMSAccess",
            "Effect": "Allow",
            "Action": [
                "kms:CreateGrant",
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:Encrypt",
                "kms:GenerateDataKey",
                "kms:GenerateDataKeyWithoutPlaintext"
            ],
            "Resource": "*"
        },
        {
            "Sid": "STSAccess",
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

---

## OPTION 2: MINIMAL POLICY (SECURITY-FOCUSED)

### Minimal Required Permissions

Save this as: `eks-minimal-policy.json`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EKSClusterBasic",
            "Effect": "Allow",
            "Action": [
                "eks:CreateCluster",
                "eks:DeleteCluster",
                "eks:DescribeCluster",
                "eks:ListClusters",
                "eks:UpdateClusterVersion",
                "eks:CreateNodegroup",
                "eks:DeleteNodegroup",
                "eks:DescribeNodegroup",
                "eks:ListNodegroups",
                "eks:UpdateNodegroupVersion",
                "eks:TagResource"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EC2Required",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeRouteTables",
                "ec2:DescribeKeyPairs",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:DeleteSecurityGroup",
                "ec2:RunInstances",
                "ec2:TerminateInstances",
                "ec2:CreateVolume",
                "ec2:DeleteVolume",
                "ec2:AttachVolume",
                "ec2:DetachVolume",
                "ec2:DescribeVolumes"
            ],
            "Resource": "*"
        },
        {
            "Sid": "IAMRequired",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:PassRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:AddRoleToInstanceProfile"
            ],
            "Resource": [
                "arn:aws:iam::*:role/eksctl-*",
                "arn:aws:iam::*:instance-profile/eksctl-*"
            ]
        },
        {
            "Sid": "CloudFormationRequired",
            "Effect": "Allow",
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:DescribeStackEvents",
                "cloudformation:UpdateStack"
            ],
            "Resource": "arn:aws:cloudformation:*:*:stack/eksctl-*/*"
        },
        {
            "Sid": "AutoScalingRequired",
            "Effect": "Allow",
            "Action": [
                "autoscaling:CreateAutoScalingGroup",
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:UpdateAutoScalingGroup"
            ],
            "Resource": "*"
        }
    ]
}
```

---

## OPTION 3: USING EXISTING AWS MANAGED POLICIES (EASIEST)

### Recommended Managed Policies to Attach:

Instead of creating custom policies, attach these AWS-managed policies:

1. **AmazonEKSClusterPolicy**
2. **AmazonEKSWorkerNodePolicy**
3. **AmazonEC2ContainerRegistryReadOnly**
4. **AmazonEKS_CNI_Policy**
5. **AmazonEBSCSIDriverPolicy**
6. **PowerUserAccess** (for testing environments)

---

## HOW TO ATTACH IAM POLICY

### Method 1: Via AWS Console (GUI)

#### Step 1: Login to AWS Console
```
https://console.aws.amazon.com/iam/
```

#### Step 2: Navigate to Your User
1. Click **Users** in left sidebar
2. Click on your username
3. Click **Add permissions** button

#### Step 3: Attach Policy
**Option A - Attach Managed Policies:**
1. Click "Attach policies directly"
2. Search for: `AmazonEKSClusterPolicy`
3. Check the box
4. Search for: `PowerUserAccess`
5. Check the box
6. Click "Next" → "Add permissions"

**Option B - Create Custom Policy:**
1. Click "Create policy"
2. Click "JSON" tab
3. Paste the comprehensive policy JSON (from above)
4. Click "Review policy"
5. Name: `EKS-Security-Research-Policy`
6. Click "Create policy"
7. Go back and attach this policy to your user

---

### Method 2: Via AWS CLI

#### Using Managed Policies:
```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get your IAM username
USERNAME="your-username"

# Attach managed policies
aws iam attach-user-policy \
    --user-name $USERNAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-user-policy \
    --user-name $USERNAME \
    --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

#### Using Custom Policy:
```bash
# Create the policy
aws iam create-policy \
    --policy-name EKS-Security-Research-Policy \
    --policy-document file://eks-full-access-policy.json

# Attach to user
aws iam attach-user-policy \
    --user-name $USERNAME \
    --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/EKS-Security-Research-Policy
```

---

## VERIFY PERMISSIONS

### Check Current Permissions:
```bash
# Verify identity
aws sts get-caller-identity

# Test EKS permissions
aws eks list-clusters --region ap-south-1

# Test EC2 permissions
aws ec2 describe-instances --region ap-south-1

# Test IAM permissions
aws iam get-user
```

### Expected Output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

## TROUBLESHOOTING IAM ISSUES

### Error: "User is not authorized to perform..."

**Solution 1: Add Missing Permission**
```bash
# Find what permission is needed from error message
# Example: "iam:PassRole"
# Add it to your policy
```

**Solution 2: Use PowerUserAccess (Quick Fix)**
```bash
aws iam attach-user-policy \
    --user-name $USERNAME \
    --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

### Error: "Cannot assume role..."

**Solution: Add PassRole Permission**
```json
{
    "Effect": "Allow",
    "Action": "iam:PassRole",
    "Resource": "*"
}
```

---

## SECURITY BEST PRACTICES

### For Production (After PhD Testing):

1. **Use Least Privilege:**
   - Remove `PowerUserAccess`
   - Use minimal policy only
   - Add resource-specific ARNs

2. **Use IAM Roles Instead of Users:**
   ```bash
   # Create role instead of user
   aws iam create-role --role-name EKSClusterRole
   ```

3. **Enable MFA:**
   - Add Multi-Factor Authentication
   - Required for sensitive operations

4. **Use Service Accounts:**
   - For applications running in EKS
   - Not for cluster creation

---

## RECOMMENDED APPROACH FOR YOUR PHD WORK

### **🎯 For Testing/Research Environment:**

Use **Option 3: Managed Policies** with:
- ✅ `PowerUserAccess` (easiest for testing)
- ✅ `AmazonEKSClusterPolicy`
- ✅ `AmazonEBSCSIDriverPolicy`

### **Why PowerUserAccess?**
- ✅ Covers all EKS, EC2, storage needs
- ✅ No permission issues during testing
- ✅ Can create/delete resources freely
- ⚠️ Only for testing accounts
- ⚠️ Never use in production

---

## QUICK VERIFICATION SCRIPT

```bash
#!/bin/bash

echo "=== IAM PERMISSIONS VERIFICATION ==="
echo ""

echo "1. Checking AWS Identity..."
aws sts get-caller-identity

echo ""
echo "2. Testing EKS Access..."
aws eks list-clusters --region ap-south-1 && echo "✓ EKS Access OK" || echo "✗ EKS Access DENIED"

echo ""
echo "3. Testing EC2 Access..."
aws ec2 describe-instances --region ap-south-1 --max-results 5 && echo "✓ EC2 Access OK" || echo "✗ EC2 Access DENIED"

echo ""
echo "4. Testing IAM Access..."
aws iam list-roles --max-items 1 && echo "✓ IAM Access OK" || echo "✗ IAM Access DENIED"

echo ""
echo "=== VERIFICATION COMPLETE ==="
```

Save as `verify-permissions.sh` and run:
```bash
chmod +x verify-permissions.sh
./verify-permissions.sh
```

---

## COST IMPLICATIONS

### Storage for IAM Policies:
- ✅ **FREE** - IAM policies have no cost
- ✅ **FREE** - User management is free
- 💰 **COST** - Only resources created (EC2, EBS, etc.)

---

## FINAL RECOMMENDATION FOR YOU

### **Before Running eksctl:**

```bash
# 1. Verify AWS CLI configured
aws configure list

# 2. Verify you have permissions
aws sts get-caller-identity

# 3. Attach PowerUserAccess (easiest for PhD testing)
# Do this via AWS Console:
# IAM → Users → Your User → Add permissions → PowerUserAccess

# 4. Verify it worked
aws eks list-clusters --region ap-south-1

# 5. If successful, proceed with cluster creation
eksctl create cluster -f security-research-cluster.yml
```

---

## ⚠️ IMPORTANT NOTES

1. **Never commit AWS credentials to Git**
2. **Delete resources after testing** to save costs
3. **Use PowerUserAccess only in test accounts**
4. **For production, use minimal permissions**

---

## SUMMARY

✅ **For PhD Testing:** Use `PowerUserAccess` managed policy
✅ **Quick Setup:** Attach via AWS Console
✅ **Verification:** Run `aws eks list-clusters`
✅ **Ready:** If no errors, proceed with cluster creation

**Need help attaching the policy? Let me know!** 🚀
