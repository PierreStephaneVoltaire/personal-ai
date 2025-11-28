import boto3
import json
import os
from datetime import datetime, timezone

ec2 = boto3.client('ec2')
GPU_INSTANCE_IDS = json.loads(os.environ.get('GPU_INSTANCE_IDS', '[]'))
MAX_UPTIME_MINUTES = int(os.environ.get('MAX_UPTIME_MINUTES', 30))

def lambda_handler(event, context):
    if not GPU_INSTANCE_IDS:
        return {'statusCode': 200, 'body': json.dumps({'message': 'No GPU instances configured', 'checked': 0})}

    stopped = []
    running = []
    already_stopped = []
    errors = []

    try:
        response = ec2.describe_instances(InstanceIds=GPU_INSTANCE_IDS)
        now = datetime.now(timezone.utc)

        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                state = instance['State']['Name']

                tier = 'unknown'
                for tag in instance.get('Tags', []):
                    if tag['Key'] == 'Tier':
                        tier = tag['Value']
                        break

                if state == 'stopped':
                    already_stopped.append(instance_id)
                    continue

                if state != 'running':
                    continue

                launch_time = instance['LaunchTime']
                uptime_minutes = (now - launch_time).total_seconds() / 60

                if uptime_minutes > MAX_UPTIME_MINUTES:
                    try:
                        ec2.stop_instances(InstanceIds=[instance_id])
                        stopped.append({'instance_id': instance_id, 'tier': tier, 'uptime_minutes': round(uptime_minutes, 1)})
                    except Exception as e:
                        errors.append({'instance_id': instance_id, 'error': str(e)})
                else:
                    remaining = MAX_UPTIME_MINUTES - uptime_minutes
                    running.append({'instance_id': instance_id, 'tier': tier, 'uptime_minutes': round(uptime_minutes, 1), 'remaining_minutes': round(remaining, 1)})

        result = {'checked': len(GPU_INSTANCE_IDS), 'max_uptime_minutes': MAX_UPTIME_MINUTES, 'stopped': stopped, 'running': running, 'already_stopped': already_stopped}
        if errors:
            result['errors'] = errors

        return {'statusCode': 200, 'body': json.dumps(result)}

    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e), 'instance_ids': GPU_INSTANCE_IDS})}
