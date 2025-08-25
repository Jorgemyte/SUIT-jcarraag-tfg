import json
import boto3

amplify = boto3.client('amplify')

def lambda_handler(event, context):
    try:
        if event['RequestType'] == 'Delete' or event['RequestType'] == 'Change':
            return {
                'statusCode': 200,
                'body': json.dumps('Successfully handled Delete or Change request')
            }
        elif event['RequestType'] == 'Create':
            amplify.start_job(appId=event['ResourceProperties']['appId'],
                              branchName=event['ResourceProperties']['branchName'],
                              jobType='RELEASE')

            return {
                'statusCode': 200,
                'body': json.dumps('Successfully triggered deployment')
            }

    except Exception as e:
        print('Received client error: %s' % e)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Received client error: {e}')
        }