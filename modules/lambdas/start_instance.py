import boto3
import json
import time
import os

ec2 = boto3.client('ec2')
GPU_INSTANCES = json.loads(os.environ.get('GPU_INSTANCES', '{}'))

def lambda_handler(event, context):
    tier = event.get('tier')
    wait_for_running = event.get('wait_for_running', True)

    if not tier:
        return {'statusCode': 400, 'body': json.dumps({'error': 'Missing required parameter: tier'})}

    if tier not in GPU_INSTANCES:
        return {'statusCode': 400, 'body': json.dumps({'error': f'Invalid tier: {tier}', 'valid_tiers': list(GPU_INSTANCES.keys())})}

    instance_info = GPU_INSTANCES[tier]
    instance_id = instance_info['instance_id']
    elastic_ip = instance_info['elastic_ip']

    try:
        response = ec2.describe_instances(InstanceIds=[instance_id])
        current_state = response['Reservations'][0]['Instances'][0]['State']['Name']

        if current_state == 'running':
            return {'statusCode': 200, 'body': json.dumps({'instance_id': instance_id, 'public_ip': elastic_ip, 'tier': tier, 'state': 'running', 'message': 'Instance already running'})}

        if current_state not in ['stopped', 'stopping']:
            return {'statusCode': 409, 'body': json.dumps({'error': f'Instance in unexpected state: {current_state}', 'instance_id': instance_id})}

        if current_state == 'stopping':
            waiter = ec2.get_waiter('instance_stopped')
            waiter.wait(InstanceIds=[instance_id], WaiterConfig={'Delay': 5, 'MaxAttempts': 60})

        ec2.start_instances(InstanceIds=[instance_id])

        if wait_for_running:
            waiter = ec2.get_waiter('instance_running')
            waiter.wait(InstanceIds=[instance_id], WaiterConfig={'Delay': 5, 'MaxAttempts': 60})
            time.sleep(10)
            final_state = 'running'
        else:
            final_state = 'pending'

        return {'statusCode': 200, 'body': json.dumps({'instance_id': instance_id, 'public_ip': elastic_ip, 'tier': tier, 'vram_gb': instance_info['vram_gb'], 'state': final_state, 'message': 'Instance started successfully'})}

    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e), 'instance_id': instance_id})}
