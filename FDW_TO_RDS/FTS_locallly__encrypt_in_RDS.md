# FTS locally, encrypt remotely in [RDS](https://aws.amazon.com/rds/postgresql/) using official tools with PostgreSQL


[HIPPA](https://en.wikipedia.org/wiki/Health_Insurance_Portability_and_Accountability_Act), [RDS](https://aws.amazon.com/rds/postgresql/) and FTS applied for searching on PostgreSQL

I've been dealing with an issue that came into my desktop from people of the
community, regarding RDS and HIPPA rules. There was a confusing scenario whether
PostgreSQL was using FTS and encryption on RDS. There are a lot of details
regarding the architecture, however I think it won't be necessary to dig into
very deeply to understand the basics of the present article moto.

[HIPPA](https://en.wikipedia.org/wiki/Health_Insurance_Portability_and_Accountability_Act)
rules are complex and if you need to deal with them, you'll probably need to go
through a careful read.

tl;dr, they tell us to store data encrypted on servers that are not in the premises.
And that's the case of RDS. However, all the communications are encrypted using
SSL protocol, but is not enough to complain with HIPPA rules.

CPU resources in RDS are expensive and not constant, which makes encryption and
FTS features not very well suited for this kind of service. I not saying that you
can't implement them, just keep in mind that a standard CPU against vCPU could
have a lot difference. If you want to benchmark your local CPU against RDS vCPU,
you can run from `psql` on both:

```
\o /dev/null
\timing
SELECT convert_from(
          pgp_sym_decrypt_bytea(
              pgp_sym_encrypt_bytea('Text to be encrypted using pgp_sym_decrypt_bytea' || gen_random_uuid()::text::bytea,'key', 'compress-algo=2'),
          'key'),
        'SQL-ASCII')
FROM generate_series(1,10000);
```

There are a lot of things and functions you can combine from the pgcrypto package.
I will try to post another blog post regarding this kind of benchmarks. In the
meantime, this query should be enough to have a rough idea of the performance difference
between RDS instance vCPU and premises server CPU.

## Architecture basics

For this POC we are going to store FTS and GPG keys locally, in a simple PostgreSQL
instance and, using a trigger, encrypt and upload transparently to RDS using the
standard FDW (Foreign Data Wrappers).

Have in mind that RDS communication is already encrypted via SSL when data flows
between server/client. It's important to clarify this, to avoid confusions between
communication encryption and storing data encrypted.

The simple trigger will split the unencrypted data between a local table storing
in a `tsvector` column (jsonb in the TODO), it will encrypt and push the encrypted
data into RDS using FDW (the standard postgres_fdw package).

## RDS structure and mirrored local structure with FDW


RDS:

```
CREATE SCHEMA enc_schema;

-- Encrpting locally, that's why we don't need to reference the key here.
create table enc_schema.__person__pgp
     (
      id bigint PRIMARY KEY,
      partial_ssn varchar(4), -- Non encrypted field for other fast search purposes
      ssn bytea,
      keyid varchar(16), -- REFERENCES keys,
      fname bytea,
      lname bytea,
      description bytea,
      auth_drugs bytea, -- This is an encrypted text vector
      patology bytea
);

CREATE INDEX ON enc_schema.__person__pgp (partial_ssn);
```

We are not going to use the `partial SSN` column, but I found it very helpful to
do RDS searches over encrypted data without fall into the need of decrypting in-the-fly.
A 4-digit SSN does not provide useful information if stolen.

Local:

```
CREATE DATABASE fts_proxy;

CREATE EXTENSION postgres_fdw;
CREATE EXTENSION pgcrypto;

CREATE SERVER RDS_server
        FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host 'dbtest1.chuxsnuhtvgl.us-east-1.rds.amazonaws.com', port '5432', dbname 'dbtest');

CREATE USER MAPPING FOR postgres
        SERVER RDS_server
        OPTIONS (user 'dbtestuser', password '<shadowed>');

create foreign table __person__pgp_RDS
(
       id bigint,
       partial_ssn varchar(4), -- Non encrypted field for other fast search purposes
       ssn bytea,
       keyid varchar(16), -- REFERENCES keys,
       fname bytea,
       lname bytea,
       description bytea,
       auth_drugs bytea, -- This is an encrypted text vector
       patology bytea
)
SERVER RDS_server
OPTIONS (schema_name 'enc_schema', table_name '__person__pgp');
```

Same table. Everytime we want to deal with the RDS table, we are going to do so
via the `__person__pgp_RDS` table, which is just a mapping table.


## Setting the keys locally

- create the keys.

use psql to insert the keys in db:

```
postgres=# \lo_import /var/lib/postgresql/9.4/main/private.key
lo_import 33583
postgres=# \lo_import /var/lib/postgresql/9.4/main/public.key
lo_import 33584
```


```
CREATE TABLE keys (
   keyid varchar(16) PRIMARY KEY,
   pub bytea,
   priv bytea
);

INSERT INTO keys VALUES ( pgp_key_id(lo_get(33583)) ,lo_get(33584), lo_get(33583));
```

## Splitting data to FTS, encrypt and push into RDS

```
CREATE SEQUENCE global_seq INCREMENT BY 1 MINVALUE 1 NO MAXVALUE;

CREATE TABLE local_search (
  id bigint PRIMARY KEY,
  _FTS tsvector
);

CREATE INDEX fts_index ON local_search USING GIST(_FTS);


CREATE TABLE __person__pgp_map
     (
      keyid varchar(16),
      ssn bigint,
      fname text,
      lname text,
      description text,
      auth_drugs text[], -- This is an encrypted text vector
      patology text
    );

-- create table __person__map_pgp (INHERITS __person__map);

CREATE TABLE __person__pgp
     (
      id bigint PRIMARY KEY,
      partial_ssn varchar(4), -- Non encrypted field for other fast search purposes
      ssn bytea,
      keyid varchar(16), -- REFERENCES keys,
      fname bytea,
      lname bytea,
      description bytea,
      auth_drugs bytea, -- This is an encrypted text vector
      patology bytea
);


CREATE OR REPLACE FUNCTION _func_get_FTS_encrypt_and_push_to_RDS() RETURNS "trigger" AS $$
DECLARE
        secret bytea;
        RDS_MAP __person__pgp_RDS%ROWTYPE;
        FTS_MAP local_search%ROWTYPE;
BEGIN

    SELECT pub INTO secret FROM keys WHERE keyid = NEW.keyid;

    RDS_MAP.fname := pgp_pub_encrypt(NEW.fname, secret);
    -- Now we encrypt the rest of the columns
    RDS_MAP.lname := pgp_pub_encrypt(NEW.lname, secret);
    RDS_MAP.auth_drugs := pgp_pub_encrypt(NEW.auth_drugs::text, secret);
    RDS_MAP.description := pgp_pub_encrypt(NEW.description, secret);
    RDS_MAP.patology := pgp_pub_encrypt(NEW.patology, secret);
    RDS_MAP.ssn := pgp_pub_encrypt(NEW.ssn::text, secret);
    RDS_MAP.partial_ssn := right( (NEW.ssn)::text,4);
    RDS_MAP.id := nextval('global_seq'::regclass);

    RDS_MAP.keyid := NEW.keyid;

    FTS_MAP.id   := RDS_MAP.id;
    FTS_MAP._FTS := (setweight(to_tsvector(NEW.fname) , 'B' ) ||
                   setweight(to_tsvector(NEW.lname), 'A') ||
                   setweight(to_tsvector(NEW.description), 'C') ||
                   setweight(to_tsvector(NEW.auth_drugs::text), 'C') ||
                   setweight(to_tsvector(NEW.patology), 'D')
                    ) ;

    INSERT INTO __person__pgp_rds SELECT (RDS_MAP.*);
    INSERT INTO local_search SELECT (FTS_MAP.*);
   RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trigger_befInsRow_name_FTS
BEFORE INSERT ON __person__pgp_map
FOR EACH ROW
EXECUTE PROCEDURE _func_get_FTS_encrypt_and_push_to_RDS();
```
