import json
import boto3

ddb = boto3.client('dynamodb')

def lambda_handler(event, context):
    try:
        if event['RequestType'] == 'Delete' or event['RequestType'] == 'Change':
            return {
                'statusCode': 200,
                'body': json.dumps('Successfully handled Delete or Change request')
            }
        elif event['RequestType'] == 'Create':
            ddb_table = event['ResourceProperties']['Table']
            for module in event['ResourceProperties']['Modules']:
                ddb.put_item(TableName=ddb_table, Item=json.loads(module))

            return {
                'statusCode': 200,
                'body': json.dumps('Successfully updated DynamoDB Table')
            }

    except Exception as e:
        print('Received client error: %s' % e)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Received client error: {e}')
        }