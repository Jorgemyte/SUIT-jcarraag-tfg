import json
import boto3

amplify = boto3.client('amplify')

def lambda_handler(event, context):
    try:
        app_id = event['appId']
        branch_name = event['branchName']

        amplify.start_job(
            appId=app_id,
            branchName=branch_name,
            jobType='RELEASE'
        )

        return {
            'statusCode': 200,
            'body': json.dumps('Successfully triggered deployment')
        }

    except Exception as e:
        print(f'Error: {e}')
        return {
            'statusCode': 500,
            'body': json.dumps(f'Received client error: {str(e)}')
        }
