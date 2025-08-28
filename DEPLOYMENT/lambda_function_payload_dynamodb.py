import json
import boto3

ddb = boto3.client('dynamodb')

def lambda_handler(event, context):
    try:
        request_type = event.get('RequestType')
        props = event.get('ResourceProperties', {})

        if request_type in ['Delete', 'Change']:
            return {
                'statusCode': 200,
                'body': json.dumps(f'Successfully handled {request_type} request')
            }

        elif request_type == 'Create':
            ddb_table = props.get('Table')
            modules = props.get('Modules', [])

            for module in modules:
                ddb.put_item(TableName=ddb_table, Item=module)

            return {
                'statusCode': 200,
                'body': json.dumps('Successfully updated DynamoDB Table')
            }

        else:
            return {
                'statusCode': 400,
                'body': json.dumps('Invalid RequestType')
            }

    except Exception as e:
        print(f'Error: {e}')
        return {
            'statusCode': 500,
            'body': json.dumps(f'Received client error: {str(e)}')
        }