#!/usr/bin/env bash 
set -e

dnf install -y jq procps-ng awscli

term_handler() {
  aws ssm delete-activation --activation-id "$ACTIVATION_ID" --region "$ECS_TASK_REGION" || true
  MANAGED_INSTANCE_ID=$(jq -r .ManagedInstanceID /var/lib/amazon/ssm/registration)
  aws ssm deregister-managed-instance --instance-id "$MANAGED_INSTANCE_ID" --region "$ECS_TASK_REGION" || true
  kill -SIGTERM "$SSM_AGENT_PID"
}
trap term_handler SIGTERM SIGINT

if [[ -z "$MANAGED_INSTANCE_ROLE_NAME" ]]; then
  echo "MANAGED_INSTANCE_ROLE_NAME not set" >&2
  exit 1
fi

if pidof amazon-ssm-agent >/dev/null; then
  echo "SSM agent already running" >&2
  exit 1
fi

TASK_METADATA=$(curl -s "${ECS_CONTAINER_METADATA_URI_V4}/task")
ECS_TASK_AVAILABILITY_ZONE=$(echo "$TASK_METADATA" | jq -r '.AvailabilityZone')
ECS_TASK_ARN=$(echo "$TASK_METADATA" | jq -r '.TaskARN')
ECS_TASK_REGION=$(echo "$ECS_TASK_AVAILABILITY_ZONE" | sed 's/.$//')

CREATE_ACTIVATION_OUTPUT=$(aws ssm create-activation \
  --iam-role "$MANAGED_INSTANCE_ROLE_NAME" \
  --tags Key=ECS_TASK_ARN,Value="$ECS_TASK_ARN" Key=ECS_TASK_AVAILABILITY_ZONE,Value="$ECS_TASK_AVAILABILITY_ZONE" Key=FAULT_INJECTION_SIDECAR,Value=true \
  --region "$ECS_TASK_REGION")

ACTIVATION_CODE=$(echo "$CREATE_ACTIVATION_OUTPUT" | jq -r .ActivationCode)
ACTIVATION_ID=$(echo "$CREATE_ACTIVATION_OUTPUT" | jq -r .ActivationId)

amazon-ssm-agent -register -code "$ACTIVATION_CODE" -id "$ACTIVATION_ID" -region "$ECS_TASK_REGION"
amazon-ssm-agent &
SSM_AGENT_PID=$!
wait "$SSM_AGENT_PID"