import json
import boto3
from typing import Dict, List

def lambda_handler(event, context):

    bedrock = boto3.client(service_name="bedrock-runtime")
    question = "what is the best car?"

    body = json.dumps({
      "max_tokens": 256,
      "messages": [{"role": "user", "content": question}],
      "anthropic_version": "bedrock-2023-05-31"
    })

    response = bedrock.invoke_model(body=body, modelId="us.anthropic.claude-3-7-sonnet-20250219-v1:0")
    response_body = json.loads(response.get("body").read())
    response_text = response_body.get("content")[0]["text"]
    response = {
      'statusCode': 200,
      'headers': {'Content-Type': 'application/json'},
      'body': '{"response":' + response_text + '}'
    }

    return response
