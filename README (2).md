# LAB 3 - Table Design and Query Tuning
In this lab you will [todo].

## Contents
* [Before You Begin](#before-you-begin)
* [Compressing and De-Normalizing](#compressing-and-de-normalizing)
* [Distributing and Sorting](#distributing-and-sorting)
* [Result Set Caching and Execution Plan Reuse](#result-set-caching-and-execution-plan-reuse)
* [Selective Filtering](#selective-filtering)
* [Join Strategies](#join-strategies)
* [Before You Leave](#before-you-leave)
 
## Before You Begin
This lab assumes you have launched a Redshift cluster, loaded it with TPC Benchmark data and can gather the following information.  If you have not launched a cluster, see [LAB 1 - Creating Redshift Clusters](../lab1/README.md).  If you have not yet loaded it, see [LAB 2 - Data Loading](../lab2/README.md).
* [Your-Redshift_Hostname]
* [Your-Redshift_Port]
* [Your-Redshift_Username]
* [Your-Redshift_Password]

## Compressing and De-Normalizing
### Standard layout
Redshift operates on high amounts of data. In order to optimize Redshift workloads, one of the key principles is to lower the amount of data stored. Diminishing this volume is achieved by using a set of compression algorithms. Instead of working on entire rows of data, containing values of different types and function, Redshift operates in a columnar fashion, this gives the opportunity to implement algorithms that can operate on single columns of data, thus greatly enhancing their efficiency. In this example we will load data into a table and test what compression scheme can be used.

Note: You can apply compression encodings to columns in tables automatically when using the COPY command into an empty table.  However, in this lab we will analyze and apply compression manually after data has been loaded to demonstrate the performance gains of using correct compression.

1. Create the customer table using the default settings, only specifying DISTKEY and SORTKEY to the customer key.
```
CREATE TABLE customer_v1 (
  c_custkey int8 NOT NULL DISTKEY SORTKEY PRIMARY KEY      ,
  c_name varchar(25) NOT NULL                              ,
  c_address varchar(40) NOT NULL                           ,
  c_nationkey int4 NOT NULL REFERENCES nation(n_nationkey) ,
  c_phone char(15) NOT NULL                                ,
  c_acctbal numeric(12,2) NOT NULL                         ,
  c_mktsegment char(10) NOT NULL                           ,
  c_comment varchar(117) NOT NULL
);
```

2. Import data from the customer table and analyze statistics.
```
INSERT INTO customer_v1
SELECT * FROM customer;
ANALYZE customer_v1;
```

3. Analyze the storage optimization options for this table. You can choose the compression scheme you want or let Redshift determine one for you. This query analyzes the data in the table and presents recommendations on how to improve storage and performances for this table. The result of this statement is important and gives you insights on how to optimize storage based on the current real data stored in the table.
```
ANALYZE COMPRESSION customer_v1;
```

### Compression Optimization
Based on the results from the previous “ANALYZE COMPRESSION” command, we can insert the same data in a new table and analyze the difference in storage.

4. Create the new customer table using the hints provided by the last compression analysis.
```
CREATE TABLE customer_v2 (
  c_custkey int8 NOT NULL ENCODE DELTA DISTKEY SORTKEY PRIMARY KEY     ,
  c_name varchar(25) NOT NULL ENCODE ZSTD                              ,
  c_address varchar(40) NOT NULL ENCODE ZSTD                           ,
  c_nationkey int4 NOT NULL ENCODE ZSTD  REFERENCES nation(n_nationkey),
  c_phone char(15) NOT NULL ENCODE ZSTD                                ,
  c_acctbal numeric(12,2) NOT NULL ENCODE ZSTD                         ,
  c_mktsegment char(10) NOT NULL ENCODE ZSTD                           ,
  c_comment varchar(117) NOT NULL ENCODE ZSTD
);
```

5. Import data from the previous table into this table and analyze statistics.
```
INSERT INTO customer_v2
SELECT * FROM customer_v1;
ANALYZE customer_v2;
```

6. Analyze the storage space for these tables, before and after compression. The table stores by column the amount of storage used in MiB. You should see about a 50% savings on the storage of the second table compared to first. This query gives you the storage requirements per column for each table, then the total storage for the table (repeated identically on each line).
```
SELECT
  CAST(d.attname AS CHAR(50)),
  SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v2%'
THEN b.size_in_mb ELSE 0 END) AS size_in_mb_v1,
  SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v2%'
THEN b.size_in_mb ELSE 0 END) AS size_in_mb_v2,
  SUM(SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v1%'
THEN b.size_in_mb ELSE 0 END)) OVER () AS total_mb_v1,
  SUM(SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v2%'
THEN b.size_in_mb ELSE 0 END)) OVER () AS total_mb_v2
FROM (
  SELECT relname, attname, attnum - 1 as colid
  FROM pg_class t
  INNER JOIN pg_attribute a ON a.attrelid = t.oid
  WHERE t.relname LIKE 'customer\_v%') d
INNER JOIN (
  SELECT name, col, MAX(blocknum) AS size_in_mb
  FROM stv_blocklist b
  INNER JOIN stv_tbl_perm p ON b.tbl=p.id
  GROUP BY name, col) b
ON d.relname = b.name AND d.colid = b.col
GROUP BY d.attname
ORDER BY d.attname;
```

### Data De-Normalizing
Compression allows the storage of “reference” data inside the fact table, removing some of the needs for “star” or “snowflake” database designs for storage optimization. In this section of the lab we will de-normalize the nation and region information into the customer table, integrating these columns and analyzing the differences.

7. Create the new customer table, de-normalizing nation and region names to be included directly in the customer table.
```
CREATE TABLE customer_v3 (
  c_custkey int8 NOT NULL ENCODE DELTA DISTKEY SORTKEY PRIMARY KEY,
  c_name varchar(25) NOT NULL ENCODE ZSTD                         ,
  c_address varchar(40) NOT NULL ENCODE ZSTD                      ,
  c_nationname char(25) NOT NULL ENCODE ZSTD                      ,
  c_regionname char(25) NOT NULL ENCODE ZSTD                      ,
  c_phone char(15) NOT NULL ENCODE ZSTD                           ,
  c_acctbal numeric(12,2) NOT NULL ENCODE ZSTD                    ,
  c_mktsegment char(10) NOT NULL ENCODE ZSTD                      ,
  c_comment varchar(117) NOT NULL ENCODE ZSTD
);
```

8. Import data from the previous table into this table. Note the joins to flatten the schema and build statistics.
```
INSERT INTO customer_v3(c_custkey, c_name, c_address, c_nationname, c_regionname, c_phone, c_acctbal, c_mktsegment, c_comment)
SELECT c_custkey, c_name, c_address, n_name, r_name, c_phone, c_acctbal, c_mktsegment, c_comment
FROM customer_v2
INNER JOIN nation ON c_nationkey = n_nationkey
INNER JOIN region ON n_regionkey = r_regionkey;

ANALYZE customer_v3;
```

9. Analyze the difference in storage space for these three versions of the customer table. Adding the columns just added the space required for this compressed column, and with the compression algorithm used, the difference is less than 2% the size of the table. This query gives you the storage requirements per column for each table, then the total storage for the table (repeated identically on each line).
```
SELECT
  CAST(d.attname AS CHAR(50)),
  SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v1%'
THEN b.size_in_mb ELSE 0 END) AS size_in_mb_v1,
  SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v2%'
THEN b.size_in_mb ELSE 0 END) AS size_in_mb_v2,
  SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v3%'
THEN b.size_in_mb ELSE 0 END) AS size_in_mb_v3,
  SUM(SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v1%'
THEN b.size_in_mb ELSE 0 END)) OVER () AS total_mb_v1,
  SUM(SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v2%'
THEN b.size_in_mb ELSE 0 END)) OVER () AS total_mb_v2,
  SUM(SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v3%'
THEN b.size_in_mb ELSE 0 END)) OVER () AS total_mb_v3
FROM (
  SELECT relname, attname, attnum - 1 as colid
  FROM pg_class t
  INNER JOIN pg_attribute a ON a.attrelid = t.oid
  WHERE t.relname LIKE 'customer\_v%') d
INNER JOIN (
  SELECT name, col, MAX(blocknum) AS size_in_mb
  FROM stv_blocklist b
  INNER JOIN stv_tbl_perm p ON b.tbl=p.id
  GROUP BY name, col) b
ON d.relname = b.name AND d.colid = b.col
GROUP BY d.attname
ORDER BY d.attname;
```

### Queries
While we won’t cover the details of Redshift queries, this section gives an example of a single query processed on all three tables. Data warehousing systems being designed for WORM (Write Once Read Many) type of workloads, the optimization of the table must be made knowing what the queries that will run on it will be. Redshift proposes system tables to analyze query performances, we will start using them.

10. Get customers from the “Asia” region from the first table.
```
SELECT COUNT(c_custkey)
FROM customer_v1 c
INNER JOIN nation n ON c.c_nationkey = n.n_nationkey
INNER JOIN region r ON n.n_regionkey = r.r_regionkey
WHERE r.r_name = 'ASIA';
```

11. From the second table.
```
SELECT COUNT(c_custkey)
FROM customer_v2 c
INNER JOIN nation n ON c.c_nationkey = n.n_nationkey
INNER JOIN region r ON n.n_regionkey = r.r_regionkey
WHERE r.r_name = 'ASIA';
```

12. And from the third table.
```
SELECT COUNT(c_custkey)
FROM customer_v3 c
WHERE c.c_regionname = 'ASIA';
```

13. Analyze the performances of each query. This query gets the 3 last queries ran against the database, and you should get your three last queries. The first executions may be comparably equal on the three queries, but if you repeat the execution multiple times (which is the case in a data warehousing environment), you will see that the query targeting the compressed table (second table) performs up to about 40% better than the one targeting the uncompressed table (first table), and that the query targeting the denormalized table (third table) has speed gains up to 50% compared to the one on the second table (or approximatively a 75% better than the one on the uncompressed table). (The numbers may vary depending on the cluster topology)
```
SELECT query, TRIM(querytxt) as SQL, starttime, endtime, DATEDIFF(microsecs, starttime, endtime) AS duration
FROM STL_QUERY
WHERE TRIM(querytxt) like '%customer%'
ORDER BY starttime DESC
LIMIT 3;
```
 
## Distributing and Sorting
### Distributing Data
One of the key features enabling Redshift’s scale is the possibility to slice the data dynamically across nodes, this can be done evenly or in a round-robin fashion (this is done by default), by a distribution key (or column) or an all distribution which puts all data in all slices.  These options give you the ability to spread out data on a cluster in distribution that can maximize the parallelization potential of the queries.
To help queries run fast, it is recommended to use as a distribution that will be used in regularly joined tables, allowing Redshift to co-locate the data of these different entities, reducing IO and network exchanges.   We will explore different distribution methods and what it does to the data and query performance.
Redshift also uses a specific Sort Column to know in advance what values of a column are in a given block, and to skip reading that entire block if the values it contains don’t fall into the range of a query.
In this sample, queries are based on customer related information (region), making the customer key a good fit for distribution key, and the filters are made on order date ranges, so using it as a sort key helps execution.

1. Create the orders table with default settings, this time changing DISTKEY to customer key and SORTKEY  to order date.
```
CREATE TABLE orders_v1 (
  o_orderkey int8 NOT NULL PRIMARY KEY                             ,
  o_custkey int8 NOT NULL DISTKEY REFERENCES customer_v3(c_custkey),
  o_orderstatus char(1) NOT NULL                                   ,
  o_totalprice numeric(12,2) NOT NULL                              ,
  o_orderdate date NOT NULL SORTKEY                                ,
  o_orderpriority char(15) NOT NULL                                ,
  o_clerk char(15) NOT NULL                                        ,
  o_shippriority int4 NOT NULL                                     ,
  o_comment varchar(79) NOT NULL
);
```

2. Import data from the existing table into this table, clean up storage, and build statistics.
```
INSERT INTO orders_v1
SELECT * FROM orders;
ANALYZE orders_v1;
```

3. Analyze compression options. You will see that they have changed from the previous entries. Compression depends directly on the data as it is stored on disk, and storage is modified by distribution and sort options.
```
ANALYZE COMPRESSION orders_v1;
```

### All Together
This last step will use the new distribution and sort keys, and the compression settings proposed by Redshift.

4. Create the orders table using the recommended compression propositions, keeping DISTKEY to customer key and SORTKEY to order date.
Copy the following statements to create the table in the database.
```
CREATE TABLE orders_v2 (
  o_orderkey int8 NOT NULL PRIMARY KEY ENCODE ZSTD                 ,
  o_custkey int8 NOT NULL DISTKEY REFERENCES customer_v3(c_custkey)
ENCODE ZSTD								       ,
  o_orderstatus char(1) NOT NULL ENCODE ZSTD                       ,
  o_totalprice numeric(12,2) NOT NULL ENCODE ZSTD                  ,
  o_orderdate date NOT NULL SORTKEY ENCODE ZSTD                    ,
  o_orderpriority char(15) NOT NULL ENCODE ZSTD                    ,
  o_clerk char(15) NOT NULL ENCODE ZSTD                            ,
  o_shippriority int4 NOT NULL ENCODE ZSTD                         ,
  o_comment varchar(79) NOT NULL ENCODE ZSTD
);
```

5. Import data and build statistics.
```
INSERT INTO orders_v2
SELECT * FROM orders_v1;
ANALYZE orders_v2;
```

6. Finally, let do one more version using ALL distribution type to put a copy of all the data in every slice of the cluster creating the largest data foot print but putting this data as close to all other data as possible.
```
CREATE TABLE orders_v3 (
  o_orderkey int8 NOT NULL PRIMARY KEY ENCODE ZSTD                 ,
  o_custkey int8 NOT NULL REFERENCES customer_v3(c_custkey)
ENCODE ZSTD								       ,
  o_orderstatus char(1) NOT NULL ENCODE ZSTD                       ,
  o_totalprice numeric(12,2) NOT NULL ENCODE ZSTD                  ,
  o_orderdate date NOT NULL SORTKEY ENCODE ZSTD                    ,
  o_orderpriority char(15) NOT NULL ENCODE ZSTD                    ,
  o_clerk char(15) NOT NULL ENCODE ZSTD                            ,
  o_shippriority int4 NOT NULL ENCODE ZSTD                         ,
  o_comment varchar(79) NOT NULL ENCODE ZSTD
) diststyle all;
```

7. Import data and build statistics.
```
INSERT INTO orders_v3
SELECT * FROM orders_v2;
ANALYZE orders_v3;
```

### Storage Analysis
As for the customers, this query will analyze the storage used by the four representations of the orders table.

8. Analyze the difference in storage space for these 3 versions of the order table. Compression allows a 50% to 60% storage reduction on the data. The third version is the largest amount of data as it stores all data in this table in all slices of the cluster.   If you wish to learn more detailed information about distributing data in a redshift cluster please see the following:
http://docs.aws.amazon.com/redshift/latest/dg/t_Distributing_data.html.
This query gives you the storage requirements per column for each table, then the total storage for the table (repeated identically on each line).
```
SELECT
  CAST(d.attname AS CHAR(50)),
  SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v1%'
THEN b.size_in_mb ELSE 0 END) AS size_in_mb_v1,
  SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v2%'
THEN b.size_in_mb ELSE 0 END) AS size_in_mb_v2,
  SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v3%'
THEN b.size_in_mb ELSE 0 END) AS size_in_mb_v3,
  SUM(SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v1%'
THEN b.size_in_mb ELSE 0 END)) OVER () AS total_mb_v1,
  SUM(SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v2%'
THEN b.size_in_mb ELSE 0 END)) OVER () AS total_mb_v2,
  SUM(SUM(CASE WHEN CAST(d.relname AS CHAR(50)) LIKE '%v3%'
THEN b.size_in_mb ELSE 0 END)) OVER () AS total_mb_v3
FROM (
  SELECT relname, attname, attnum - 1 as colid
  FROM pg_class t
  INNER JOIN pg_attribute a ON a.attrelid = t.oid
  WHERE t.relname LIKE 'orders\_v%') d
INNER JOIN (
  SELECT name, col, MAX(blocknum) AS size_in_mb
  FROM stv_blocklist b
  INNER JOIN stv_tbl_perm p ON b.tbl=p.id
  GROUP BY name, col) b
ON d.relname = b.name AND d.colid = b.col
GROUP BY d.attname
ORDER BY d.attname;
```
### Queries
The query execution speed is also impacted by the distribution settings. This last part will issue the same query on the four versions of the order table, and analyze the time taken to execute these queries.

9. Get, for the year 1995, some information on the orders passed by the customers depending on their market segment, in Asia. This query is for the first table.
```
SELECT c_mktsegment, COUNT(o_orderkey) AS orders_count,
AVG(o_totalprice) AS medium_amount,
SUM(o_totalprice) AS orders_revenue
FROM orders_v1 o
INNER JOIN customer_v3 c ON o.o_custkey = c.c_custkey
WHERE o_orderdate BETWEEN '1995-01-01' AND '1995-12-31' AND
c_regionname = 'ASIA'
GROUP BY c_mktsegment;
```

10. Same query for the second table.
```
SELECT c_mktsegment, COUNT(o_orderkey) AS orders_count,
AVG(o_totalprice) AS medium_amount,
SUM(o_totalprice) AS orders_revenue
FROM orders_v2 o
INNER JOIN customer_v3 c ON o.o_custkey = c.c_custkey
WHERE o_orderdate BETWEEN '1995-01-01' AND '1995-12-31' AND
c_regionname = 'ASIA'
GROUP BY c_mktsegment;
```

11. For the third table. You will notice that the order of results has changed. This is due to the change in sorting and distribution, since we did not order the resultset (no ORDER clause), the “natural” (storage) order applies.
```
SELECT c_mktsegment, COUNT(o_orderkey) AS orders_count,
AVG(o_totalprice) AS medium_amount,
SUM(o_totalprice) AS orders_revenue
FROM orders_v3 o
INNER JOIN customer_v3 c ON o.o_custkey = c.c_custkey
WHERE o_orderdate BETWEEN '1995-01-01' AND '1995-12-31' AND
c_regionname = 'ASIA'
GROUP BY c_mktsegment;
```

12. Analyze the performances of each query. This query gets the 3 last queries ran against the database. The results go up to around 75% query time improvement with the right distribution, sort and compression schemes (orders_v1 vs orders_v2).  The ALL distribution (v3) should really be used only if a dimension table cannot be collocated with the fact table or other important joining tables, you can improve query performance significantly by distributing the entire table to all of the nodes. Using ALL distribution multiplies storage space requirements and increases load times and maintenance operations, so you should weigh all factors before choosing ALL distribution. (The numbers will vary depending on the cluster topology)
```
SELECT query, TRIM(querytxt) as SQL, starttime, endtime, DATEDIFF(microsecs, starttime, endtime) AS duration
FROM STL_QUERY
WHERE TRIM(querytxt) like '%orders_v%JOIN%'
ORDER BY starttime DESC
LIMIT 3;
```

## Result Set Caching and Execution Plan Reuse
Redshift enables a result set cache to speed up retrieval of data when it knows that the data in the underlying table has not changed.  It can also re-use compiled query plans when only the predicate of the query has changed.

1. Execute the following query and note the query execution time.  Since this is the first execution of this query Redshift will need to compile the query as well as cache the result set.
```
SELECT c_mktsegment, o_orderpriority, sum(o_totalprice)
FROM Customer_v3 c
JOIN Orders_v2 o on c.c_custkey = o.o_custkey
GROUP BY c_mktsegment, o_orderpriority
```

2. Execute the same query a second time and note the query execution time.  In the second execution redshift will leverage the result set cache and return immediately.
```
SELECT c_mktsegment, o_orderpriority, sum(o_totalprice)
FROM Customer_v3 c
JOIN Orders_v2 o on c.c_custkey = o.o_custkey
GROUP BY c_mktsegment, o_orderpriority
```

3. Update data in the table and run the query again. When data in an underlying table has changed Redshift will be aware of the change and invalidate the result set cache associated to the query.  Note the execution time is not as fast as Step 2, but faster than Step 1 because while it couldn’t re-use the cache it could re-use the compiled plan.
```
UPDATE customer_v3
SET c_mktsegment = c_mktsegment
WHERE c_mktsegment = 'MACHINERY';
VACUUM DELETE ONLY customer_v3;
SELECT c_mktsegment, o_orderpriority, sum(o_totalprice)
FROM Customer_v3 c
JOIN Orders_v2 o on c.c_custkey = o.o_custkey
GROUP BY c_mktsegment, o_orderpriority;
```

4. Execute a new query with a predicate and note the query execution time.  Since this is the first execution of this query Redshift will need to compile the query as well as cache the result set.
```
SELECT c_mktsegment, count(1)
FROM Customer_v3 c
WHERE c_mktsegment = 'MACHINERY'
GROUP BY c_mktsegment;
```
5. Execute the query with a slightly different predicate and note that the execution time is faster than the prior execution even though a very similar amount of data was scanned and aggregated.  This behavior is due to the re-use of the compile cache because only the predicate has changed.  This type of pattern is typical for BI reporting where the SQL pattern remains consistent with different users retrieving data associated to different predicates.
```
SELECT c_mktsegment, count(1)
FROM Customer_v3 c
WHERE c_mktsegment = 'BUILDING'
GROUP BY c_mktsegment;
```

## Selective Filtering
Redshift takes advantage of zone maps which allows the optimizer to skip reading blocks of data when it knows that the filter criteria will not be matched.   In the case of the orders_v3 table, because we have defined a sort key on the o_order_date, queries leveraging that field as a predicate will return much faster.

6. Execute the following two queries noting the execution time of each.  The first query is to ensure the plan is compiled.  The second has a slightly different filter condition to ensure the result cache cannot be used.
```
select count(1), sum(o_totalprice)
FROM orders_v3
WHERE o_orderdate between '1992-07-05' and '1992-07-07'
```
```
select count(1), sum(o_totalprice)
FROM orders_v3
WHERE o_orderdate between '1992-07-07' and '1992-07-09'
```
7. Execute the following two queries noting the execution time of each.  The first query is to ensure the plan is compiled.  The second has a slightly different filter condition to ensure the result cache cannot be used. You will notice the second query takes significantly longer than the second query in the previous step even though the number of rows which were aggregated is similar.  This is due to the first query's ability to take advantage of the Sort Key defined on the table.
```select count(1), sum(o_totalprice)
FROM orders_v3
where o_orderkey < 600001
```
```
select count(1), sum(o_totalprice)
FROM orders_v3
where o_orderkey < 600002
```

## Join Strategies
Because or the distributed architecture of Redshift, in order to process data which is joined together, data may have to be broadcast from one node to another.  It’s important to analyze the explain plan on a query to identify which join strategies is being used and how to improve it.

8. Execute an EXPLAIN on the following query.  If you recall, both of these tables are distributed on the custkey.  This results in a join strategy of “Hash Join DS_DIST_NONE” and a relatively low overall “cost”.
```
EXPLAIN
SELECT c_mktsegment, o_orderpriority, sum(o_totalprice)
FROM Customer_v3 c
JOIN Orders_v2 o on c.c_custkey = o.o_custkey
GROUP BY c_mktsegment, o_orderpriority
```

9. Execute an EXPLAIN on the following query.  If you recall, this version of the orders is distributed on the orderkey.  This results in a join strategy of “Hash Join DS_BCAST_INNER” and a relatively high overall “cost”.
```
EXPLAIN
SELECT c_mktsegment, o_orderpriority, sum(o_totalprice)
FROM Customer_v3 c
JOIN Orders o on c.c_custkey = o.o_custkey
GROUP BY c_mktsegment, o_orderpriority
```

10. Create a new version of the orders tables which is both distributed and sorted on the values as the customer table.  Execute an EXPLAIN and notice this results in a join strategy of “Merge Join DS_DIST_NONE” with the lowest cost of the three.
```
CREATE TABLE orders_v4
DISTKEY(o_custkey) SORTKEY (o_custkey) as
SELECT * FROM orders_v2;
```
```
EXPLAIN
SELECT c_mktsegment, o_orderpriority, sum(o_totalprice)
FROM Customer_v3 c
JOIN Orders o on c.c_custkey = o.o_custkey
GROUP BY c_mktsegment, o_orderpriority;
```

11. Execute an EXPLAIN plan on the following query which is missing the join condition.  This results in a join strategy of “XN Nested Loop DS_BCAST_INNER” and throws a warning about the cartesian product.  
```
EXPLAIN
SELECT * FROM region, nation
```

## Before You Leave
If you are done using your cluster, please think about decommissioning it to avoid having to pay for unused resources.
