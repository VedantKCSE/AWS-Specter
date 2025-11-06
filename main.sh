#!/bin/bash

# --- Configuration ---
# Customize this list to include all AWS regions you actively use.
# Include a comprehensive list to ensure nothing is missed!
ALL_REGIONS="us-east-1"

# --- Formatting Variables ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
INFO_LEVEL="${YELLOW}[INFO]${NC}"
FOUND_LEVEL="${RED}[FOUND]${NC}"
CHECK_COUNT=0
FOUND_ANYTHING=false

echo -e "${CYAN}--- 🔎 AWS Cleanup Checker (v4.0) - Production Ready Scan ---${NC}"
echo -e "${CYAN}Scanning regions: ${ALL_REGIONS}${NC}"
echo "=========================================================="
echo ""

# --- Function to Check a Service in a Region (Unified & Improved) ---
check_regional_service() {
    SERVICE_NAME=$1
    COMMAND=$2
    QUERY=$3
    JQ_FILTER=$4
    REGION=$5
    
    CHECK_COUNT=$((CHECK_COUNT + 1))
    
    # Run the AWS CLI command and capture JSON output
    # Using '2>/dev/null' to suppress typical service/region not enabled errors
    OUTPUT=$(aws $COMMAND --region "$REGION" --query "$QUERY" 2>/dev/null)
    
    # Check if the output is NOT empty
    if [[ "$OUTPUT" != "[]" ]] && [[ "$OUTPUT" != "" ]] && [[ "$OUTPUT" != "null" ]]; then
        FOUND_ANYTHING=true
        echo -e "${FOUND_LEVEL} ${SERVICE_NAME}:${NC}"
        # Use jq to format the output
        echo "$OUTPUT" | jq -r "$JQ_FILTER"
    fi
}

# --- Regional Checks Loop ---
for REGION in $ALL_REGIONS; do
    echo -e "${GREEN}Scanning Region: $REGION...${NC}"
    REGION_FOUND_FLAG=false

    # 1. EC2 INSTANCES (Running/Stopped - Charged for Compute/Storage)
    check_regional_service \
        "EC2 Instances (Not Terminated)" \
        "ec2 describe-instances" \
        'Reservations[*].Instances[?State.Name!=`terminated` && State.Name!=`shutting-down`].{ID:InstanceId, State:State.Name, Type:InstanceType}' \
        '.[] | "\tID: " + .ID + ", State: " + .State + ", Type: " + .Type' \
        $REGION
        
    # 2. EBS VOLUMES (Available/In-use - Charged for Storage)
    check_regional_service \
        "EBS Volumes (Not Deleted)" \
        "ec2 describe-volumes" \
        'Volumes[?State!=`deleted`].{ID:VolumeId, State:State, Size:Size, Attached:Attachments[0].InstanceId}' \
        '.[] | "\tID: " + .ID + ", State: " + .State + ", Size: " + (.Size | to_string) + "GB, AttachedTo: " + if .Attached then .Attached else "N/A" end' \
        $REGION

    # 3. RDS DB Instances (Active/Stopped - Charged for Compute/Storage/Snapshots)
    check_regional_service \
        "RDS DB Instances (Active/Stopped)" \
        "rds describe-db-instances" \
        'DBInstances[?DBInstanceStatus!=`deleting` && DBInstanceStatus!=`deleted`].{ID:DBInstanceIdentifier, Status:DBInstanceStatus, Engine:Engine}' \
        '.[] | "\tID: " + .ID + ", Status: " + .Status + ", Engine: " + .Engine' \
        $REGION

    # 4. DYNAMODB TABLES (Charged for Storage/Provisioned Capacity)
    check_regional_service \
        "DynamoDB Tables (Active)" \
        "dynamodb list-tables" \
        'TableNames[*]' \
        '.[] | "\tName: " + .' \
        $REGION
    
    # 5. ELASTIC IPS (Unassociated EIPs - Charged per hour)
    check_regional_service \
        "Unattached Elastic IPs (EIPs)" \
        "ec2 describe-addresses" \
        'Addresses[?AssociationId==null].{PublicIp:PublicIp, AllocationId:AllocationId}' \
        '.[] | "\tPublicIP: " + .PublicIp + ", AllocationID: " + .AllocationId' \
        $REGION
        
    # 6. NAT GATEWAYS (HIGH COST: Charged per hour + heavy data processing fees)
    check_regional_service \
        "NAT Gateways (Active)" \
        "ec2 describe-nat-gateways" \
        'NatGateways[?State==`available`].{ID:NatGatewayId, State:State, VPC:VpcId}' \
        '.[] | "\tID: " + .ID + ", State: " + .State + ", VPC: " + .VPC' \
        $REGION

    # 7. ELASTIC LOAD BALANCERS (Charged per hour)
    check_regional_service \
        "Load Balancers (ELB/ALB/NLB)" \
        "elbv2 describe-load-balancers" \
        'LoadBalancers[*].{Name:LoadBalancerName, Type:Type, DNS:DNSName}' \
        '.[] | "\tName: " + .Name + ", Type: " + .Type + ", DNS: " + .DNS' \
        $REGION
        
    # 8. EFS FILE SYSTEMS (Charged for Storage)
    check_regional_service \
        "EFS File Systems (Active)" \
        "efs describe-file-systems" \
        'FileSystems[?LifeCycleState==`available`].{ID:FileSystemId, Name:Name}' \
        '.[] | "\tID: " + .ID + ", Name: " + .Name' \
        $REGION
    
    # 9. LAMBDA FUNCTIONS (Storage and Provisioned Concurrency costs)
    check_regional_service \
        "Lambda Functions (Active)" \
        "lambda list-functions" \
        'Functions[*].{Name:FunctionName, Runtime:Runtime}' \
        '.[] | "\tName: " + .Name + ", Runtime: " + .Runtime' \
        $REGION
        
    # 10. API GATEWAYS (Charged per hour for V2 WebSocket/HTTP APIs)
    check_regional_service \
        "API Gateways (Active)" \
        "apigatewayv2 get-apis" \
        'Items[*].{Name:Name, ProtocolType:ProtocolType, ID:ApiId}' \
        '.[] | "\tID: " + .ID + ", Name: " + .Name + ", Protocol: " + .ProtocolType' \
        $REGION

    # 11. WORLD-OPEN SECURITY GROUPS (CRITICAL SECURITY RISK - Not billable, but critical for cleanup)
    # Checks for SG rules open to 0.0.0.0/0 on all protocols (Inbound)
    check_regional_service \
        "World-Open Security Groups (SECURITY RISK)" \
        "ec2 describe-security-groups" \
        'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].{ID:GroupId, Name:GroupName, VPC:VpcId}' \
        '.[] | "\tID: " + .ID + ", Name: " + .Name + ", VPC: " + .VPC' \
        $REGION
    
    echo "" # Add a separator between regions

done

# --- Global/Account Service Checks (Run Once) ---
echo -e "${GREEN}Scanning Global/Account Services...${NC}"
echo "--------------------------------------"

# A. S3 BUCKETS (Storage cost is the main driver)
echo -e "${FOUND_LEVEL} S3 Buckets (Must manually verify contents/lifecycle policy):${NC}"
aws s3api list-buckets --query 'Buckets[*].Name' --output text | tr '\t' '\n' | sed 's/^/\t- /'
echo ""

# B. CLOUDWATCH LOG GROUPS (Storage cost is a common forgotten expense)
echo -e "${FOUND_LEVEL} CloudWatch Log Groups (Storage cost):${NC}"
aws logs describe-log-groups --region us-east-1 --query 'logGroups[*].logGroupName' --output text | tr '\t' '\n' | sed 's/^/\t- /'
echo ""

# C. EC2 KEY PAIRS (Security cleanup)
echo -e "${INFO_LEVEL} EC2 Key Pairs (Review unused keys for security cleanup):${NC}"
aws ec2 describe-key-pairs --region us-east-1 --query 'KeyPairs[*].KeyName' --output text | tr '\t' '\n' | sed 's/^/\t- /'
echo ""

# D. NON-DEFAULT VPCS (Container for costly resources)
echo -e "${INFO_LEVEL} Non-Default VPCs (Review for hidden costs like NAT Gateways):${NC}"
aws ec2 describe-vpcs --region us-east-1 --filters "Name=is-default,Values=false" --query 'Vpcs[*].{ID:VpcId, State:State}' --output json | jq -r '.[] | "\tID: " + .ID + ", State: " + .State'
echo ""


echo "=========================================================="
if [ "$FOUND_ANYTHING" = true ]; then
    echo -e "${RED}ACTION REQUIRED: Resources marked [FOUND] incur charges and should be reviewed/deleted.${NC}"
else
    echo -e "${GREEN}Scan Complete. No chargeable resources were immediately flagged across all checked regions.${NC}"
fi
echo -e "${YELLOW}Total Service Checks Run: $CHECK_COUNT${NC}"
