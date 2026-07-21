import os
import boto3
import logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)
ecs_client = boto3.client('ecs') 
def lambda_handler(event, context):
    logger.info(f"Received approved remediation event: {event}")
    incident_type = event.get('IncidentType')
    ecs_cluster = os.environ.get('ECS_CLUSTER_NAME')
    ecs_service = os.environ.get('ECS_SERVICE_NAME')
    if not incident_type:
        logger.error("Remediation execution rejected: Missing 'IncidentType' parameter.")
        return { 'statusCode': 400, 'body': 'Missing IncidentType.'}

    try:
        if incident_type == 'NETWORK_BLACKHOLE':
            logger.info(f"orcing rolling redeployment for ECS Service: {ecs_service} in cluster: {ecs_cluster}")
            response = ecs_client.update_service(
                cluster = ecs_cluster,
                service = ecs_service,
                forceNewDeployment = True
            )
            deployment_id = response ['service']['deployments'][0]['id']
            logger.info(f"ECS Rolling redeployment active. Deployment ID: {deployment_id}")
            return {
                'statusCode': 200,
                'body': f"Successfully forced rolling container redeployment for service {ecs_service}."
            }

        else:
             logger.warning(f"Unrecognized incident signature: {incident_type}. No mutation executed.")
             return {'statusCode': 400, 'body': f"Unsupported incident type: {incident_type}"}

    except Exception as e:
        logger.error(f"Critical execution error during remediation: {e}")
        raise


            