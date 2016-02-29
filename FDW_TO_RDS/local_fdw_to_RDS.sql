
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
OPTIONS (schema_name 'enc_schema', table_name '__person__pgp')
;



emanuel@3laptop ~/git/RDS_HIPPA_FTS $ sudo cp /home/emanuel/imedicare/data/private.key /var/lib/postgresql/9.4/main/
emanuel@3laptop ~/git/RDS_HIPPA_FTS $ sudo chown postgres: /var/lib/postgresql/9.4/main/private.key
emanuel@3laptop ~/git/RDS_HIPPA_FTS $ sudo cp /home/emanuel/imedicare/data/public.key /var/lib/postgresql/9.4/main/
emanuel@3laptop ~/git/RDS_HIPPA_FTS $ sudo chown postgres: /var/lib/postgresql/9.4/main/public.key


CREATE TABLE keys (
   keyid varchar(16) PRIMARY KEY,
   pub bytea,
   priv bytea
);


-- postgres=# \lo_import /var/lib/postgresql/9.4/main/private.key
-- lo_import 33583
-- postgres=# \lo_import /var/lib/postgresql/9.4/main/public.key
-- lo_import 33584

INSERT INTO keys VALUES ( pgp_key_id(lo_get(33583)) ,lo_get(33584), lo_get(33583));

-- test
-- postgres=# select pgp_pub_decrypt(_FTS, priv,'') from __person__pgp_rds, keys limit 3;
--                                                                         pgp_pub_decrypt
------------------------------------------------------------------------------------------------------------------------------------------------------------------
--
-- 'amoxicillin':5C 'argyria':9 'cymbalta':4C 'horacio':1B 'prednisone':6C 'smith':2A 'some':3C 'viagra':8C 'xanax':7C
-- 'acetaminophen':6C 'alprazolam':4C 'asthma':11 'azithromycin':7C 'citalopram':10C 'cymbalta':5C 'omeprazole':8C 'ortigoza':2A 'prednisone':9C 'text':3C 'tim':1B
-- (3 rows)



CREATE TABLE drugsList ( id serial PRIMARY KEY, drugName text);

INSERT INTO drugsList(drugName) SELECT p.nameD FROM regexp_split_to_table(
'Acetaminophen
Adderall
Alprazolam
Amitriptyline
Amlodipine
Amoxicillin
Ativan
Atorvastatin
Azithromycin
Ciprofloxacin
Citalopram
Clindamycin
Clonazepam
Codeine
Cyclobenzaprine
Cymbalta
Doxycycline
Gabapentin
Hydrochlorothiazide
Ibuprofen
Lexapro
Lisinopril
Loratadine
Lorazepam
Losartan
Lyrica
Meloxicam
Metformin
Metoprolol
Naproxen
Omeprazole
Oxycodone
Pantoprazole
Prednisone
Tramadol
Trazodone
Viagra
Wellbutrin
Xanax
Zoloft', '\n') p(nameD);

CREATE OR REPLACE FUNCTION get_drugs_random(int)
       RETURNS text[] AS
      $BODY$
      WITH rdrugs(dname) AS (
        SELECT drugName FROM drugsList p ORDER BY random() LIMIT $1
      )
      SELECT array_agg(dname) FROM rdrugs ;
$BODY$
LANGUAGE 'sql' VOLATILE;



CREATE SEQUENCE global_seq INCREMENT BY 1 MINVALUE 1 NO MAXVALUE;


CREATE TABLE local_search (
  id bigint PRIMARY KEY,
  _FTS tsvector
);

CREATE INDEX fts_index ON local_search USING GIST(_FTS);


create table __person__pgp_map
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

create table __person__pgp
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


INSERT INTO __person__pgp_map
  SELECT
      '76CDA76B5C1EA9AB',
       round(random()*1000000000),
      ('{Romulo,Ricardo,Romina,Fabricio,Francisca,Noa,Laura,Priscila,Tiziana,Ana,Horacio,Tim,Mario}'::text[])[round(random()*12+1)],
      ('{Perez,Ortigoza,Tucci,Smith,Fernandez,Samuel,Veloso,Guevara,Calvo,Cantina,Casas,Korn,Rodriguez,Ike,Baldo,Vespi}'::text[])[round(random()*15+1)],
      ('{some,random,text,goes,here}'::text[])[round(random()*5+1)] ,
      get_drugs_random(round(random()*10)::int),
      ('{Anotia,Appendicitis,Apraxia,Argyria,Arthritis,Asthma,Astigmatism,Atherosclerosis,Athetosis,Atrophy,Abscess,Influenza,Melanoma}'::text[])[round(random()*12+1)]
      FROM generate_series(1,50) ;
