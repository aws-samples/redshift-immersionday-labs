# Query Aurora PostgreSQL using Federation

## Contents
* [Before You Begin](#before-you-begin)
* [Launch an Aurora PostgreSQL DB](#launch-an-aurora-postgresql-db)
* [Load Sample Data](#load-sample-data)
* [Setup External Schema](#setup-external-schema)
* [Execute Federated Queries](#execute-federated-queries)
* [Execute ETL processes](#execute-etl-processes)
* [Before You Leave](#before-you-leave)

## Before You Begin
This lab assumes you have launched a Redshift cluster and have loaded it with sample TPC benchmark data. If you have not completed these steps, see [Lab 2. Data Loading](../lab2/README.md).

Note: As of 3/1/2020, the federation feature in Redshift is in Public Preview only.  To enable your cluster for this feature, restore the latest snapshot of your cluster and select **Preview --> preview_features** for the *Maintenance Track* option.

## Launch an Aurora PostgreSQL DB
Navigate to the RDS Console and Launch a new Amazon Aurora PostgreSQL database.
```
https://console.aws.amazon.com/rds/home?#launch-dbinstance:gdb=false;s3-import=false
```

1. Choose **Amazon Aurora** for the Engine, **PostgreSQL** for the Edition and **Serverless**.

<table><tr><td><img src=../images/RDS1.png></td></tr></table>

2. Scroll to Settings and specify a DB Cluster Identifier, Master username and Master password.

<table><tr><td><img src=../images/RDS2.png></td></tr></table>

3. Scroll to the Additional connectivity configuration and check the **Data API** option to enable access via the online Query Editor.

<table><tr><td><img src=../images/RDS3.png></td></tr></table>


Note: This will create a DB within your Default VPC.  If you would like to configure the DB to launch in a specific VPC, make the appropriate changes.

## Load Sample Data
Navigate to the online query editor and connect to your newly launched database.  
```
https://console.aws.amazon.com/rds/home?#query-editor:
```
1. Enter the appropriate values for the Database instance, username, and password captured earlier.  Use the value **postgres** for the name of the database.

<table><tr><td><img src=../images/RDS4.png></td></tr></table>


2. Execute the following script to create a table and load some sample data.
```sql
drop table if exists customer;
create table customer (
  C_CUSTKEY bigint NOT NULL PRIMARY KEY,
  C_NAME varchar(25),
  C_ADDRESS varchar(40),
  C_NATIONKEY bigint,
  C_PHONE varchar(15),
  C_ACCTBAL decimal(18,4),
  C_MKTSEGMENT varchar(10),
  C_COMMENT varchar(117),
  C_UPDATETS timestamp);

insert into Customer values
(1, 'Customer#000000001', '1 Main St.', 1, '555-555-5555', 1234, 'BUILDING', 'comment1', current_timestamp),
(2, 'Customer#000000002', '2 Main St.', 2, '555-555-5555', 1235, 'MACHINERY', 'comment2', current_timestamp),
(3, 'Customer#000000003', '3 Main St.', 3, '555-555-5555', 1236, 'AUTOMOBILE', 'comment3', current_timestamp),
(4, 'Customer#000000004', '4 Main St.', 4, '555-555-5555', 1237, 'HOUSEHOLD', 'comment4', current_timestamp),
(5, 'Customer#000000005', '5 Main St.', 5, '555-555-5555', 1238, 'FURNITURE', 'comment5', current_timestamp);
```

## Setup External Schema
1. Determine the Secrets ARN associated to your RDS DB Credentials by navigating to the following service and selecting the **rds-db-credentials** associated to your Aurora PostgreSQL DB.
```
https://console.aws.amazon.com/secretsmanager/home?#/listSecrets
```
2. Create an IAM Policy called **RedshiftPostgreSQLSecret-lab** with the following privileges and replacing [YOUR SECRET ARN] with the one from above.  Modify the Role associated to your Redshift cluster and attach this policy to that role.
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AccessSecret",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds"
            ],
            "Resource": "[YOUR SECRET ARN]"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetRandomPassword",
                "secretsmanager:ListSecrets"
            ],
            "Resource": "*"
        }
    ]
}
```
3. Log into your Redshift Cluster using the Query Editor application.  Execute the following statement replacing the values for [YOUR POSTGRES HOST], [YOUR IAM ROLE] and [YOUR SECRET ARN].

```sql
CREATE EXTERNAL SCHEMA postgres
FROM POSTGRES
DATABASE 'postgres'
URI '[YOUR POSTGRES HOST]'
IAM_ROLE '[YOUR IAM ROLE]'
SECRET_ARN '[YOUR SECRET ARN]'
```

## Execute Federated Queries
At this point you will have access to all the tables in your PostgreSQL database via the *postgres* schema.  

1. Execute a simple select from the federated customer table.

```sql
select * From postgres.customer;
```

2. Execute a join between the federated customer table and the local region and nation tables.
```sql
select c_name, n_name, r_name
From postgres.customer
join nation on c_nationkey = n_nationkey
join region on n_regionkey = r_regionkey

```


## Execute ETL Processes
You can also query federated tables for use in ETL processes.  Traditionally, these tables needed to be staged locally in order to perform change detection logic, however, with federation, they can be queried and joined directly.

```sql
insert into customer (c_custkey, c_name, c_address, c_nationkey, c_acctbal, c_mktsegment, c_comment)
select p.c_custkey, p.c_name, p.c_address, p.c_nationkey, p.c_acctbal, p.c_mktsegment, p.c_comment
from postgres.customer p
left join customer c on p.c_custkey = c.c_custkey
where c_updatets > current_date and c.c_custkey is null

update customer
set c_custkey = p.c_custkey, c_name = p.c_name, c_address = p.c_address, c_nationkey = p.c_nationkey,
    c_acctbal = p.c_acctbal, c_mktsegment = p.c_mktsegment, c_comment = p.c_comment
from postgres.customer p
where p.c_custkey = customer.c_custkey
and c_updatets > current_date
```

## Before You Leave
If you are done using your cluster, please think about decommissioning it to avoid having to pay for unused resources.
