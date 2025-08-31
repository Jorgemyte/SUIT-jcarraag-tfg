import json
import boto3

amplify = boto3.client('amplify')

def lambda_handler(event, context):
    print("Raw event:", event)

    try:
        if isinstance(event, str):
            event = json.loads(event)

        app_id = event['appId']
        branch_name = event['branchName']

        print(f"Triggering Amplify job for appId={app_id}, branchName={branch_name}")

        response = amplify.start_job(
            appId=app_id,
            branchName=branch_name,
            jobType='RELEASE'
        )

        print("Amplify response:", response)

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