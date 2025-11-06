# 🛡️ AWS Budget Guardian: Multi-Region Cleanup Checker (v4.0)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![GitHub stars](https://img.shields.io/github/stars/VedantKCSE/aws-cleanup-checker?style=social)](https://github.com/YOUR_GITHUB_USERNAME/aws-cleanup-checker/stargazers)

**Stop accidental cloud billing!** A simple, powerful, and fast command-line tool for indie developers and small teams to audit AWS accounts for forgotten, chargeable resources across all regions. This script targets the most common "silent cost killers" that lead to unexpected bills.

## ✨ Features & Coverage

This script performs **13 critical checks** across all specified AWS regions, helping you identify resources that are actively incurring charges or pose a security risk:

| Category | Service Checked | Cost Focus |
| :--- | :--- | :--- |
| **Compute** | EC2 Instances (Stopped/Running) | Compute time & Storage |
| **Networking** | Unattached Elastic IPs (EIPs) | Hourly charge when unassociated |
| **Networking** | **NAT Gateways** | High hourly charge + Data Processing fees |
| **Networking** | Load Balancers (ELB/ALB/NLB) | Hourly charge |
| **Security** | World-Open Security Groups | **Critical Security Risk** (`0.0.0.0/0`) |
| **Storage** | EBS Volumes (Available/In-use) | Persistent Storage charges |
| **Storage** | EFS File Systems (Active) | Persistent Storage charges |
| **Storage** | S3 Buckets | Storage & Request fees |
| **Database** | RDS Instances (Active/Stopped) | Compute, Storage, & Snapshots |
| **Database** | DynamoDB Tables | Provisioned Capacity & Storage |
| **Serverless** | Lambda Functions | Storage & Provisioned Concurrency |
| **Serverless** | API Gateways (v2) | Hourly charge for HTTP/WebSocket APIs |
| **Monitoring** | CloudWatch Log Groups | Storage charges |

***

## 🚀 Quick Start Guide

### 1. Prerequisites

You must have the following tools installed on your Linux/macOS machine:

* **AWS CLI:** Properly configured with credentials that have read-only access to all services.
* **`jq`:** A command-line JSON processor (`sudo apt install jq` or `brew install jq`).

### 2. Setup

1.  **Clone the Repository:**
    ```bash
    git clone [https://github.com/YOUR_GITHUB_USERNAME/aws-cleanup-checker.git](https://github.com/YOUR_GITHUB_USERNAME/aws-cleanup-checker.git)
    cd aws-cleanup-checker
    ```
2.  **Save the Script:** Ensure the file is named `aws-cleanup-checker.sh`.
3.  **Make it Executable:**
    ```bash
    chmod +x aws-cleanup-checker.sh
    ```

### 3. Execution

Run the script directly from your terminal:

```bash
./aws-cleanup-checker.sh
```

### 4. Customizing Regions
**Before running**, you may edit the ALL_REGIONS variable at the top of the script (line 4) to include only the regions relevant to your account for faster scanning, though scanning all known regions is recommended for full security.

```bash
# Example customization in aws-cleanup-checker.sh
ALL_REGIONS="us-east-1 us-west-2 eu-central-1"
```

📊 Interpreting the Output (Cleanup Guide)

The script provides a clear, scannable report. Pay close attention to the colored flags:

| Output Flag | Meaning | Action Recommended |
| :--- | :--- | :--- |
| 🔴 [FOUND] | This resource is **active and likely incurring charges** or is a major security risk. | **Immediate review and deletion** required. |
| 🟡 [INFO] | This resource is not directly chargeable but should be reviewed for **security** or **organizational cleanup**. | Review for unused keys or check associated resources. |

| Forgotten Resource | Recommended AWS CLI Deletion Command (Example) |
| :--- | :--- |
| Unattached EIP | `aws ec2 release-address --allocation-id alloc-12345678` |
| Unattached EBS Volume | `aws ec2 delete-volume --volume-id vol-abcdef12345` |
| NAT Gateway | `aws ec2 delete-nat-gateway --nat-gateway-id nat-12345678` |
| DynamoDB Table | `aws dynamodb delete-table --table-name MyForgottenTable` |
| S3 Bucket | `aws s3 rb s3://my-old-bucket-name --force` (deletes contents and bucket) |

***

🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any suggestions or feature requests are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

***

📜 License

Distributed under the MIT License. See `LICENSE` for more information.

***
