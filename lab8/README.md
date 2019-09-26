## Lab 8 – Querying Nested JSON
In this lab, we show you how to query Nested JSON datatypes (array, struct, map) using Amazon Redshift as well as how to leverage Redshift Spectrum to load nested data types into flattened structures.

## Contents
* [Before You Begin](#before-you-begin)
* [Background](#background)
* [Infer JSON Schema](#infer-json-schema)
* [Review JSON Schema](#review-json-schema)
* [Query JSON data using Redshift Spectrum](#query-json-data-using-redshift-spectrum)
* [Load JSON data using Redshift Spectrum](#load-json-data-using-redshift-spectrum)
* [Before You Leave](#before-you-leave)

## Before You Begin
This lab assumes you have launched a Redshift cluster in US-WEST-2 (Oregon), and can gather the following information. If you have not launched a cluster, see [LAB 1 - Creating Redshift Clusters](../lab1/README.md).
* [Your-Redshift_Hostname]
* [Your-Redshift_Port]
* [Your-Redshift_Username]
* [Your-Redshift_Password]
* [Your-Redshift_Role]
* [Your-AWS-Account_Id]
* [Your-Glue_Role]

It also assumes you have access to a configured client tool. For more details on configuring SQL Workbench/J as your client tool, see [Lab 1 - Creating Redshift Clusters : Configure Client Tool](../lab1/README.md#configure-client-tool). As an alternative you can use the Amazon Redshift provided online Query Editor which does not require an installation.


## Background
Nested data support enables Redshift customers to directly query their nested data from Redshift through Spectrum.  Customers already have nested data in their Amazon S3 data lake.  For example, commonly java applications often use JSON as a standard for data exchange. Redshift Spectrum supports nested data types for the following format
* Apache Parquet
* Apache ORC
* JSON
* Amazon Ion

**Complex Data Types** 

*Struct* - this type allows multiple values of any type to be grouped together into a new type. Values are identified by a *Field Name* and *Field Type*.  In the following example, the *Name* field is a struct which has two nested fields of the *string* type.

```
{Name: {Given:"John", Family:"Smith"}}
{Name: {Given:"Jenny", Family:"Doe"}}
{Name: {Given:"Andy", Family:"Jones"}}
```
```
Name struct<Given: string, Family: string>
```

*Array/Map* - this type defines a collection of an arbitrary number of elements of a certain type.  In the following example, the *Phones* field is an array of elements with the *string* type.

```
{Phones: ["123-457789"]}
{Phones: ["858-8675309","415-9876543"]}
{Phones: []}
```
```
Phones array<string>
```

Create even more complex data types by (deeply) nesting complex data types like struct, array or map.
```
{Orders: [ {Date: "2018-03-01 11:59:59", Price: 100.50}, 
           {Date: "2018-03-01 09:10:00", Price: 99.12} ]
}
{Orders: [] }
{Orders: [ {Date: "2018-03-02 08:02:15", Price: 13.50} ]
```
```
Orders array<struct<Date: timestamp, Price: double precision>>
```

## Infer JSON Schema
We will create AWS Glue crawler to infer the JSON dataset

1. Navigate to the Glue Crawler Page. https://console.aws.amazon.com/glue/home?#catalog:tab=crawlers.  Click on *Add crawler*.
<table><tr><td><img src=../images/lab8_crawler01.png></td></tr></table>

2. Name the crawler *nested-json* and click *Next*
<table><tr><td><img src=../images/lab8_crawler02.png></td></tr></table>

3. Select *Data Stores* as source type and click *Next*
<table><tr><td><img src=../images/lab8_crawler03.png></td></tr></table>

4. Set the data store as *s3*, select the radio *Specified path in another account*, and enter the path *s3://redshift-immersionday-labs/data/nested-json*. 

<table><tr><td><img src=../images/lab8_crawler04.png></td></tr></table>

5. Click – *No* for *Add another data store* and click *Next*
<table><tr><td><img src=../images/lab8_crawler05.png></td></tr></table>

6. Select *Create an IAM role*, specify the name of the role as below and click *Next*
<table><tr><td><img src=../images/lab8_crawler06.png></td></tr></table>

7. Select *Run on demand* for the frequency and click *Next*
<table><tr><td><img src=../images/lab8_crawler07.png></td></tr></table>

8. Click *Add database* to create an new AWS Glue database
<table><tr><td><img src=../images/lab8_crawler08.png></td></tr></table>

9. Specify database name as *nested-json* and click *Create* 
<table><tr><td><img src=../images/lab8_crawler09.png></td></tr></table>

10. Specify a table prefix of *cus* and click *Next*
<table><tr><td><img src=../images/lab8_crawler10.png></td></tr></table>

11. Review all settings and click *Finish*
<table><tr><td><img src=../images/lab8_crawler11.png></td></tr></table>

12. We have now created the crawler, click on *Run it now*. The crawler will automatically infer the schema of the JSON datasets.
<table><tr><td><img src=../images/lab8_crawler12.png></td></tr></table>

13.When the crawler finishes, you will see the crawler in *Ready* status and you will see *Tables added* as *1*
<table><tr><td><img src=../images/lab8_crawler13.png></td></tr></table>

 
## Review JSON Schema
Navigate to the Glue Catalog and click on the *cusnested-json* table. 

```
https://console.aws.amazon.com/glue/home?#catalog:tab=tables
```
Click – *Edit Schema* and review the schema created by the crawler.
<table><tr><td><img src=../images/lab8_table1.png></td></tr></table>

The JSON dataset contains struct, array columns. 
<table><tr><td><img src=../images/lab8_table2.png></td></tr></table>

Note: The Crawler created a superset of the columns in the table definition. Customer_1.JSON file has c_comments key but customer_2.JSON and customer_3.JSON does not have c_comment column/key.

## Query JSON data using Redshift Spectrum

1. Login to Redshift and create external schema

```sql
CREATE external SCHEMA nested_json
FROM data catalog DATABASE 'nested-json' 
IAM_ROLE 'arn:aws:iam::[Your-AWS-Account_Id]:role/[Your-Redshift_Role]'
CREATE external DATABASE if not exists;
```

2. Run the following query to view customer name, address and comments

```sql
SELECT cust.c_name, cust.c_address, cust.c_comment
FROM nested_json.cusnested_json cust
ORDER BY cust.c_name;
```

You will see the following output. Notice how c_comment key was not present in customer_2 and customer_3 JSON file. This demonstrates that the format of files could be different and using the Glue crawler you can create a superset of columns – supporting schema evolution. The files which have the key will return the value and the files that do not have that key will return null.
<table><tr><td><img src=../images/lab8_query1.png></td></tr></table>

Filter the data by nationkey and address:

```sql
SELECT cust.c_name, 
  cust.c_nationkey, 
  cust.c_address
FROM nested_json.cusnested_json cust
WHERE cust.c_nationkey = '-2013'
  AND cust.c_address like 'AAA%';
```
<table><tr><td><img src=../images/lab8_query1.1.png></td></tr></table>



3. Query the Order struct and check how many orders each customer has:
```
Orders array<
  struct<
    o_orderstatus:String, 
    o_totalprice:Double,
    o_orderdate:String,
    o_order_priority:String,
    o_clerk:String,
    o_ship_priority:Int,
    o_comment:String
  >
>
```

```sql
SELECT  cust.c_name, count(*)
FROM nested_json.cusnested_json cust,
     cust.orders.order co  
GROUP BY cust.c_name
ORDER BY cust.c_name;
```
<table><tr><td><img src=../images/lab8_query2.png></td></tr></table>

4. Query the Order arrays to flatten or un-nest the Order columns. Notice how the scalar in an array is queried using alias (e.g. co.o_totalprice).  Struct data type is queried using the dot-notation (e.g. cust.c_name).

```sql
SELECT cust.c_name,
           co.o_orderstatus,
           co.o_totalprice,
           to_date(co.o_orderdate, 'YYYY-MM-DD'),
           co.o_order_priority,
           co.o_clerk,
           co.o_ship_priority,
           co.o_comment  
FROM nested_json.cusnested_json cust,
           cust.orders.order co;
```
<table><tr><td><img src=../images/lab8_query3.png></td></tr></table>

5. Further un-nest lineitems by using a left join.

```sql
SELECT cust.c_name,
       to_date(co.o_orderdate, 'YYYY-MM-DD'),  
       litem.l_linenumber,
       litem.l_quantity,
       litem.l_extendedprice,
       litem.l_discount,
       litem.l_tax,
       litem.l_returnflag,
       litem.l_linestatus,
       to_date(litem.l_shipdate, 'YYYY-MM-DD'),
       to_date(litem.l_commitdate, 'YYYY-MM-DD'),
       to_date(litem.l_receiptdate, 'YYYY-MM-DD'),
       litem.l_shipinstruct,
       litem.l_shipmode,
       litem.l_comment,
FROM nested_json.cusnested_json cust
LEFT JOIN cust.orders.order co on true
LEFT JOIN co.lineitems.lineitem litem on true	
;
```

6. Find the retail price for each customer

```sql
SELECT cust.c_name,
  sum(litem.p_retailprice)
FROM  nested_json.cusnested_json cust
LEFT JOIN cust.orders.order co on true
LEFT JOIN co.lineitems.lineitem litem on true	
GROUP BY cust.c_name;
```

7. Aggregating nested data with subqueries

```sql
SELECT cust.c_name, 
       (SELECT COUNT(*) FROM cust.orders.order o) AS ordercount,
       (SELECT COUNT(*) FROM cust.orders.order o, o.lineitems.lineitem l) as lineitemcount
FROM nested_json.cusnested_json cust
ORDER BY c_name;
```
<table><tr><td><img src=../images/lab8_query4.png></td></tr></table>

## Load JSON data using Redshift Spectrum
Let’s leverage Redshift Spectrum to ingest JSON data set in Redshift local tables. This is one usage pattern to leverage Redshift Spectrum for ELT. We will also join Redshift local tables to external tables in this example.

1. Create Redshift local staging tables.

```sql
DROP TABLE IF EXISTS  public.stg_customer;
create table stg_customer 
( c_custkey     integer not null,
  c_name        varchar(25) not null,
  c_address     varchar(40) not null,
  c_nationkey   integer not null,
  c_phone       char(15) not null,
  c_acctbal     decimal(15,2) not null,
  c_mktsegment  char(10) not null,
  c_comment varchar(117) not null)
  backup no;
  
DROP TABLE IF EXISTS  public. stg_orders;

create table stg_orders  
( o_orderkey       integer not null,
  o_custkey        integer not null,
  o_orderstatus    char(1) not null,
  o_totalprice     decimal(15,2) not null,
  o_orderdate      date not null,
  o_orderpriority  char(15) not null,  
  o_clerk          varchar(20) not null, 
  o_shippriority   integer not null,
  o_comment        varchar(100) not null)
backup no;

DROP TABLE IF EXISTS  public. stg_lineitem;
create table stg_lineitem 
( l_orderkey    integer not null,
  l_partname    varchar(50),
  l_supplyname  varchar(50),
  l_linenumber  integer not null,
  l_quantity    decimal(15,2) not null,
  l_extendedprice  decimal(15,2) not null,
  l_discount    decimal(15,2) not null,
  l_tax         decimal(15,2) not null,
  l_returnflag  char(1) not null,
  l_linestatus  char(1) not null,
  l_shipdate    date not null,
  l_commitdate  date not null,
  l_receiptdate date not null,
  l_shipinstruct char(25) not null,
  l_shipmode     char(10) not null,
  l_comment varchar(44) not null)
backup no;
```

2. Write the ELT code to ingest JSON data residing on s3 using Redshift Spectrum into Redshift local tables.

```sql
BEGIN TRANSACTION;

TRUNCATE TABLE public.stg_customer;
INSERT INTO public.stg_customer
(        c_custkey
       , c_name
       , c_address
       , c_nationkey
       , c_phone
       , c_acctbal
       , c_mktsegment
       , c_comment
)
SELECT row_number() over (order by cust.c_name),
       cust.c_name, 
       cust.c_address,
       cust.c_nationkey,
       cust.c_phone,
       cust.c_acctbal,
       cust.c_mktsegment,
       coalesce(cust.c_comment,'unk')
FROM nested_json.cusnested_json cust;

TRUNCATE TABLE public.stg_orders ;
INSERT INTO public.stg_orders 
(        o_orderkey
       , o_custkey
       , o_orderstatus
       , o_totalprice
       , o_orderdate
       , o_orderpriority
       , o_clerk
       , o_shippriority
       , o_comment
)
SELECT row_number() over (order by cust.c_name) 
       ,stgcust.c_custkey
       ,co.o_orderstatus
       ,co.o_totalprice
       ,to_date(co.o_orderdate, 'YYYY-MM-DD') 
       ,co.o_order_priority
       ,co.o_clerk
       ,co.o_ship_priority
       ,co.o_comment
FROM nested_json.cusnested_json cust, 
     cust.orders.order co,
     public.stg_customer stgcust
WHERE cust.c_name = stgcust.c_name;


TRUNCATE TABLE stg_lineitem;
INSERT INTO public.stg_lineitem 
(        l_orderkey
       , l_partname
       , l_supplyname
       , l_linenumber
       , l_quantity
       , l_extendedprice
       , l_discount
       , l_tax
       , l_returnflag
       , l_linestatus
       , l_shipdate
       , l_commitdate
       , l_receiptdate
       , l_shipinstruct
       , l_shipmode
       , l_comment
)

SELECT so.o_orderkey 
       , litem.p_name
       , litem.s_name
       , litem.l_linenumber
       , litem.l_quantity
       , litem.l_extendedprice
       , litem.l_discount
       , litem.l_tax
       , litem.l_returnflag
       , litem.l_linestatus
       , to_date(litem.l_shipdate, 'YYYY-MM-DD')
       , to_date(litem.l_commitdate, 'YYYY-MM-DD')
       , to_date(litem.l_receiptdate, 'YYYY-MM-DD')
       , litem.l_shipinstruct
       , litem.l_shipmode
       , litem.l_comment
FROM nested_json.cusnested_json cust, 
     cust.orders.order co,
     co.lineitems.lineitem litem,
     public.stg_orders so,
     public.stg_customer sc
WHERE to_date(co.o_orderdate, 'YYYY-MM-DD') = so.o_orderdate
    and co.o_totalprice = so.o_totalprice
    and so.o_custkey = sc.c_custkey
    and sc.c_name = cust.c_name
;

END TRANSACTION;
```

3. Query the counts in each of the tables.

```sql
SELECT 'customer', count(*) from stg_customer
UNION ALL
SELECT 'orders', count(*) from stg_orders
UNION ALL
SELECT 'lineitem', count(*) from stg_lineitem;
``` 
<table><tr><td><img src=../images/lab8_query5.png></td></tr></table>

4. Consider wrapping the ELT code in a Redshift stored procedure

```sql
CREATE OR REPLACE PROCEDURE sp_loadtpch(indate in date) as
$$
declare
  integer_var int;
begin

RAISE INFO 'running staging for date %',  indate;

TRUNCATE TABLE public.stg_customer;
INSERT INTO public.stg_customer
(        c_custkey
       , c_name
       , c_address
       , c_nationkey
       , c_phone
       , c_acctbal
       , c_mktsegment
       , c_comment
)
SELECT row_number() over (order by cust.c_name),
       cust.c_name, 
       cust.c_address,
       cust.c_nationkey,
       cust.c_phone,
       cust.c_acctbal,
       cust.c_mktsegment,
       coalesce(cust.c_comment,'unk')
FROM nested_json.cusnested_json cust;

GET DIAGNOSTICS integer_var := ROW_COUNT;
RAISE INFO 'rows inserted into stg_customer = %', integer_var;

TRUNCATE TABLE public.stg_orders ;
INSERT INTO public.stg_orders 
(        o_orderkey
       , o_custkey
       , o_orderstatus
       , o_totalprice
       , o_orderdate
       , o_orderpriority
       , o_clerk
       , o_shippriority
       , o_comment
)
SELECT row_number() over (order by cust.c_name) 
       ,stgcust.c_custkey
       ,co.o_orderstatus
       ,co.o_totalprice
       ,to_date(co.o_orderdate, 'YYYY-MM-DD') 
       ,co.o_order_priority
       ,co.o_clerk
       ,co.o_ship_priority
       ,co.o_comment
FROM nested_json.cusnested_json cust, 
     cust.orders.order co,
     public.stg_customer stgcust
WHERE cust.c_name = stgcust.c_name;

GET DIAGNOSTICS integer_var := ROW_COUNT;
RAISE INFO 'rows inserted into stg_orders = %', integer_var;

TRUNCATE TABLE stg_lineitem;
INSERT INTO public.stg_lineitem 
(        l_orderkey
       , l_partname
       , l_supplyname
       , l_linenumber
       , l_quantity
       , l_extendedprice
       , l_discount
       , l_tax
       , l_returnflag
       , l_linestatus
       , l_shipdate
       , l_commitdate
       , l_receiptdate
       , l_shipinstruct
       , l_shipmode
       , l_comment
)
SELECT so.o_orderkey 
       , litem.p_name
       , litem.s_name
       , litem.l_linenumber
       , litem.l_quantity
       , litem.l_extendedprice
       , litem.l_discount
       , litem.l_tax
       , litem.l_returnflag
       , litem.l_linestatus
       , to_date(litem.l_shipdate, 'YYYY-MM-DD')
       , to_date(litem.l_commitdate, 'YYYY-MM-DD')
       , to_date(litem.l_receiptdate, 'YYYY-MM-DD')
       , litem.l_shipinstruct
       , litem.l_shipmode
       , litem.l_comment
FROM nested_json.cusnested_json cust, 
     cust.orders.order co,
     co.lineitems.lineitem litem,
     public.stg_orders so,
     public.stg_customer sc
WHERE to_date(co.o_orderdate, 'YYYY-MM-DD') = so.o_orderdate
    and co.o_totalprice = so.o_totalprice
    and so.o_custkey = sc.c_custkey
    and sc.c_name = cust.c_name
;
	 
GET DIAGNOSTICS integer_var := ROW_COUNT;
RAISE INFO 'rows inserted into stg_lineitem = %', integer_var;
 
END;	  
$$ LANGUAGE plpgsql;
```

Execute the procedure
```
call sp_loadtpch(current_date);
```

## Before You Leave
If you are done using your cluster, please think about decommissioning it to avoid having to pay for unused resources. For Redshift Spectrum best practices refer to this blog:
https://aws.amazon.com/blogs/big-data/10-best-practices-for-amazon-redshift-spectrum/
