import json
import boto3
import cfnresponse

ddb = boto3.client('dynamodb')

def lambda_handler(event, context):
    try:
        if event['RequestType'] == 'Delete' or event['RequestType'] == 'Change':
            cfnresponse.send(event,
                            context,
                            cfnresponse.SUCCESS,
                            {})
            return 0
        elif event['RequestType'] == 'Create':
            ddb_table = event['ResourceProperties']['Table']
            for module in event['ResourceProperties']['Modules']:
                ddb.put_item(TableName=ddb_table,Item=json.loads(module))

            responseData = {'Success': 'Successfully updated DynamoDB Table'}
            cfnresponse.send(event,
                            context,
                            cfnresponse.SUCCESS,
                            responseData)

    except Exception as e:
        print('Received client error: %s' % e)
        responseData = {'Failed': 'Received client error: %s' % e}
        cfnresponse.send(event,
                        context,
                        cfnresponse.SUCCESS,
                        responseData)