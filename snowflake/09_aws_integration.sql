-- ============================================================================
-- 09_AWS_INTEGRATION.SQL — AWS services for Ride-Hailing & Super-App Analytics
-- Account: <YOUR_AWS_ACCOUNT_ID> | Region: ap-southeast-1
-- Skip this script for Snowflake-only build
-- ============================================================================
USE DATABASE RIDE_HAILING_ANALYTICS;
USE SCHEMA APP;

-- ==================== AMAZON BEDROCK ====================
-- Network rule for Bedrock API access
CREATE OR REPLACE NETWORK RULE APP.BEDROCK_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('bedrock-runtime.ap-southeast-1.amazonaws.com:443');

-- Secret for AWS credentials (replace with actual keys)
CREATE OR REPLACE SECRET APP.AWS_BEDROCK_SECRET
  TYPE = GENERIC_STRING
  SECRET_STRING = '{"aws_key_id":"YOUR_KEY","aws_secret_key":"YOUR_SECRET","region":"ap-southeast-1"}';

-- External Access Integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION aws_indonesia_digital_economy_ride_hailing_BEDROCK_EAI
  ALLOWED_NETWORK_RULES = (RIDE_HAILING_ANALYTICS.APP.BEDROCK_NETWORK_RULE)
  ALLOWED_AUTHENTICATION_SECRETS = (RIDE_HAILING_ANALYTICS.APP.AWS_BEDROCK_SECRET)
  ENABLED = TRUE
  COMMENT = 'Bedrock access for Ride-Hailing & Super-App Analytics';

-- UDF to call Bedrock Claude
CREATE OR REPLACE FUNCTION APP.BEDROCK_GENERATE(prompt VARCHAR)
  RETURNS VARCHAR
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('requests', 'boto3')
  HANDLER = 'invoke_bedrock'
  EXTERNAL_ACCESS_INTEGRATIONS = (aws_indonesia_digital_economy_ride_hailing_BEDROCK_EAI)
  SECRETS = ('aws_creds' = RIDE_HAILING_ANALYTICS.APP.AWS_BEDROCK_SECRET)
AS $$
import json, boto3, _snowflake

def invoke_bedrock(prompt):
    creds = json.loads(_snowflake.get_generic_secret_string('aws_creds'))
    client = boto3.client(
        'bedrock-runtime',
        region_name=creds['region'],
        aws_access_key_id=creds['aws_key_id'],
        aws_secret_access_key=creds['aws_secret_key']
    )
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": prompt}]
    })
    response = client.invoke_model(
        modelId='us.anthropic.claude-sonnet-4-5-20250929-v1:0',
        contentType='application/json',
        accept='application/json',
        body=body
    )
    result = json.loads(response['body'].read())
    return result['content'][0]['text']
$$;

-- ==================== KINESIS / IOT CORE INGESTION ====================
-- Snowpipe from Kinesis Data Stream
-- Stream ARN: arn:aws:kinesis:ap-southeast-1:<YOUR_AWS_ACCOUNT_ID>:stream/aws-indonesia-digital-economy-ride-hailing-stream

CREATE OR REPLACE PIPE RAW.REALTIME_PIPE
  AUTO_INGEST = TRUE
  INTEGRATION = 'aws_indonesia_digital_economy_ride_hailing_S3_INT'
  COMMENT = 'Auto-ingest from Kinesis via S3 delivery stream'
AS
COPY INTO RAW.TRIPS
FROM @RAW.LANDING_STAGE/realtime/
FILE_FORMAT = (TYPE = 'JSON');

