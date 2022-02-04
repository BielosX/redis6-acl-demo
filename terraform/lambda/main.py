import boto3
import redis
import os

def handle(event, context):
    port = int(os.environ['REDIS_PORT'])
    url = os.environ['REDIS_URL']
    secret_arn = os.environ['SECRET_ARN']
    sm_client = boto3.client('secretsmanager')
    user_pass = sm_client.get_secret_value(SecretId=secret_arn)['SecretString']
    user = os.environ['USER_NAME']
    client = redis.Redis(host=url,
                         port=port,
                         ssl=True,
                         username=user,
                         password=user_pass)
    client.set('foo', 'bar')
    return client.get('foo')