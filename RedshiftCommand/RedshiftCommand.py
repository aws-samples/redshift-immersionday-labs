#!/usr/bin/env python
from __future__ import print_function

import os
import sys

# add the lib directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), "lib"))

import json
import pg8000
from botocore.vendored import requests

__version__ = "1.4"

#### Static Configuration
ssl = True
debug = True
pg8000.paramstyle = "qmark"

def command_handler(event, context):
    if event['RequestType'] != 'Create':
        sendResponseCfn (event, context, 'SUCCESS', '')
    else:
        user = event['ResourceProperties']['UserName']
        password = event['ResourceProperties']['UserPassword']
        database = event['ResourceProperties']['Database']
        host = event['ResourceProperties']['HostName']
        port = int(event['ResourceProperties']['Port'])
        cmd = event['ResourceProperties']['SQLCommand']

        if debug:
            print('User is: %s' % user)

        # Connect to the cluster
        try:
            if debug:
                print('Connecting to Redshift: %s' % host)

            conn = pg8000.connect(database=database, user=user, password=password, host=host, port=port, ssl=ssl)
            if debug:
                print('Successfully Connected to Cluster')

            # create a new cursor for methods to run through
            cursor = conn.cursor()
            statement = ''
            try:
                for statement in cmd.split(';'):
                    if statement.strip(' ') != '':
                        if debug:
                            print("Running Statement: %s" % statement)
                        result = cursor.execute(statement)
                        print(result)
                conn.commit()
                conn.close()
                sendResponseCfn (event, context, 'SUCCESS', '')

            except Exception as e:
                reason = "Exception running statement %s" % statement
                print(reason)
                print(e)
                conn.close()
                sendResponseCfn (event, context, 'FAILED', reason)

        except:
            reason = 'Redshift Connection Failed: exception %s' % sys.exc_info()[1]
            print(reason)
            responseStatus = 'FAILED'
            sendResponseCfn (event, context, responseStatus, reason)

def sendResponseCfn (event, context, responseStatus, reason):
    response_body = {'Status': responseStatus,
                     'Reason': reason,
                     'PhysicalResourceId': context.log_stream_name,
                     'StackId': event['StackId'],
                     'RequestId': event['RequestId'],
                     'LogicalResourceId': event['LogicalResourceId']
                     }
    requests.put(event['ResponseURL'], data=json.dumps(response_body))
