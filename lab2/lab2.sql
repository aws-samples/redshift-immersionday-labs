DROP TABLE IF EXISTS partsupp CASCADE;
DROP TABLE IF EXISTS lineitem CASCADE;
DROP TABLE IF EXISTS supplier CASCADE;
DROP TABLE IF EXISTS part CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS nation CASCADE;
DROP TABLE IF EXISTS region CASCADE;

CREATE TABLE region (
  R_REGIONKEY bigint NOT NULL PRIMARY KEY,
  R_NAME varchar(25),
  R_COMMENT varchar(152))
diststyle all;

CREATE TABLE nation (
  N_NATIONKEY bigint NOT NULL PRIMARY KEY,
  N_NAME varchar(25),
  N_REGIONKEY bigint REFERENCES region(R_REGIONKEY),
  N_COMMENT varchar(152))
diststyle all;

create table customer (
  C_CUSTKEY bigint NOT NULL PRIMARY KEY,
  C_NAME varchar(25),
  C_ADDRESS varchar(40),
  C_NATIONKEY bigint REFERENCES nation(N_NATIONKEY),
  C_PHONE varchar(15),
  C_ACCTBAL decimal(18,4),
  C_MKTSEGMENT varchar(10),
  C_COMMENT varchar(117))
diststyle all;

create table orders (
  O_ORDERKEY bigint NOT NULL PRIMARY KEY,
  O_CUSTKEY bigint REFERENCES customer(C_CUSTKEY),
  O_ORDERSTATUS varchar(1),
  O_TOTALPRICE decimal(18,4),
  O_ORDERDATE Date,
  O_ORDERPRIORITY varchar(15),
  O_CLERK varchar(15),
  O_SHIPPRIORITY Integer,
  O_COMMENT varchar(79))
distkey (O_ORDERKEY)
sortkey (O_ORDERDATE);

create table part (
  P_PARTKEY bigint NOT NULL PRIMARY KEY,
  P_NAME varchar(55),
  P_MFGR  varchar(25),
  P_BRAND varchar(10),
  P_TYPE varchar(25),
  P_SIZE integer,
  P_CONTAINER varchar(10),
  P_RETAILPRICE decimal(18,4),
  P_COMMENT varchar(23))
diststyle all;

create table supplier (
  S_SUPPKEY bigint NOT NULL PRIMARY KEY,
  S_NAME varchar(25),
  S_ADDRESS varchar(40),
  S_NATIONKEY bigint REFERENCES nation(n_nationkey),
  S_PHONE varchar(15),
  S_ACCTBAL decimal(18,4),
  S_COMMENT varchar(101))
diststyle all;

create table lineitem (
  L_ORDERKEY bigint NOT NULL REFERENCES orders(O_ORDERKEY),
  L_PARTKEY bigint REFERENCES part(P_PARTKEY),
  L_SUPPKEY bigint REFERENCES supplier(S_SUPPKEY),
  L_LINENUMBER integer NOT NULL,
  L_QUANTITY decimal(18,4),
  L_EXTENDEDPRICE decimal(18,4),
  L_DISCOUNT decimal(18,4),
  L_TAX decimal(18,4),
  L_RETURNFLAG varchar(1),
  L_LINESTATUS varchar(1),
  L_SHIPDATE date,
  L_COMMITDATE date,
  L_RECEIPTDATE date,
  L_SHIPINSTRUCT varchar(25),
  L_SHIPMODE varchar(10),
  L_COMMENT varchar(44),
PRIMARY KEY (L_ORDERKEY, L_LINENUMBER))
distkey (L_ORDERKEY)
sortkey (L_RECEIPTDATE);

create table partsupp (
  PS_PARTKEY bigint NOT NULL REFERENCES part(P_PARTKEY),
  PS_SUPPKEY bigint NOT NULL REFERENCES supplier(S_SUPPKEY),
  PS_AVAILQTY integer,
  PS_SUPPLYCOST decimal(18,4),
  PS_COMMENT varchar(199),
PRIMARY KEY (PS_PARTKEY, PS_SUPPKEY))
diststyle even;

COPY region FROM 's3://redshift-immersionday-labs/data/region/region.tbl.lzo' iam_role '${Role}' region 'us-west-2' lzop delimiter '|' COMPUPDATE PRESET;
COPY nation FROM 's3://redshift-immersionday-labs/data/nation/nation.tbl.' iam_role '${Role}' region 'us-west-2' lzop delimiter '|' COMPUPDATE PRESET;
COPY customer FROM 's3://redshift-immersionday-labs/data/customer/customer.tbl.' iam_role '${Role}' region 'us-west-2' lzop delimiter '|' COMPUPDATE PRESET;
COPY orders FROM 's3://redshift-immersionday-labs/data/orders/orders.tbl.' iam_role '${Role}' region 'us-west-2' lzop delimiter '|' COMPUPDATE PRESET;
COPY part FROM 's3://redshift-immersionday-labs/data/part/part.tbl.' iam_role '${Role}' region 'us-west-2' lzop delimiter '|' COMPUPDATE PRESET;
COPY supplier FROM 's3://redshift-immersionday-labs/data/supplier/supplier.json' manifest iam_role '${Role}' region 'us-west-2' lzop delimiter '|' COMPUPDATE PRESET;
COPY lineitem FROM 's3://redshift-immersionday-labs/data/lineitem/lineitem.tbl.' iam_role '${Role}' region 'us-west-2' lzop delimiter '|' COMPUPDATE PRESET;
COPY partsupp FROM 's3://redshift-immersionday-labs/data/partsupp/partsupp.tbl.' iam_role '${Role}' region 'us-west-2' lzop delimiter '|' COMPUPDATE PRESET;
