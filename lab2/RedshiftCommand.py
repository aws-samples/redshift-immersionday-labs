import json
import boto3
from botocore.vendored import requests
from awsglue.utils import getResolvedOptions
import logging
import sys
import os
import site
from setuptools.command import easy_install
install_path = os.environ['GLUE_INSTALLATION']
easy_install.main( ["--install-dir", install_path, "https://files.pythonhosted.org/packages/83/03/10902758730d5cc705c0d1dd47072b6216edc652bc2e63a078b58c0b32e6/pg8000-1.12.5.tar.gz"] )
reload(site)
import pg8000
from urlparse import urlparse

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)


#Required Parameters
args = getResolvedOptions(sys.argv, [
        'UserName',
        'UserPassword',
        'Database',
        'HostName',
        'Port',
        'SQLScript',
        'Role'])

user = args['UserName']
password = args['UserPassword']
database = args['Database']
host = args['HostName']
port = int(args['Port'])
cmd = args['SQLScript']
role = args['Role']

print('User is: %s' % user)

# Connect to the cluster
try:
    print('Connecting to Redshift: %s' % host)
    pg8000.paramstyle = "qmark"
    conn = pg8000.connect(database=database, user=user, password=password, host=host, port=port, ssl=True)
    conn.autocommit = True
    print('Successfully Connected to Cluster')

    # create a new cursor for methods to run through
    cursor = conn.cursor()
    statement = ''
    try:
        import boto3
        s3 = boto3.resource('s3')
        o = urlparse(cmd)
        bucket = o.netloc
        key = o.path
        obj = s3.Object(bucket, key.lstrip('/'))
        cmd = obj.get()['Body'].read().decode('utf-8')

        for statement in cmd.split(';'):
            if statement.strip(' ') != '':
                print("Running Statement: %s" % statement.replace('${Role}', role))
                result = cursor.execute(statement.replace('${Role}', role))
                print(result)
        conn.commit()
        conn.close()

    except Exception as e:
        reason = "Exception running statement %s" % statement
        print(reason)
        print(e)
        conn.close()

except:
    reason = 'Redshift Connection Failed: exception %s' % sys.exc_info()[1]
    print(reason)
