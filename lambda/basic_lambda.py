import json
import boto3
import subprocess
import os
import time


def lambda_handler(event, context):
    # Trigger some really time consuming code <---- RUN IT AFTER RETURNING 

    return {  #         <---- RETURN THIS RIGHT AWAY 
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda! Real Test')
    }
