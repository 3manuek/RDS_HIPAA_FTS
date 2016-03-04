
-- BEGIN preparing the environement

CREATE DATABASE fts_proxy;

CREATE EXTENSION postgres_fdw;
CREATE EXTENSION pgcrypto;

CREATE SERVER RDS_server
        FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host 'dbtest1.chuxsnuhtvgl.us-east-1.rds.amazonaws.com', port '5432', dbname 'dbtest');


CREATE USER MAPPING FOR postgres
        SERVER RDS_server
        OPTIONS (user 'dbtestuser', password '<shadowed>');

CREATE FOREIGN table __person__pgp_RDS
(
       id bigint,
       source varchar(8),
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



-- $ sudo cp /home/emanuel//data/private.key /var/lib/postgresql/9.4/main/
-- $ sudo chown postgres: /var/lib/postgresql/9.4/main/private.key
-- $ sudo cp /home/emanuel/keyfolder/data/public.key /var/lib/postgresql/9.4/main/
-- $ sudo chown postgres: /var/lib/postgresql/9.4/main/public.key


CREATE TABLE keys (
   keyid varchar(16) PRIMARY KEY,
   pub bytea,
   priv bytea
);


-- A little bit more secure and elegant way, you can do the same in RDS as this is
-- a psql feature:

-- postgres=# \lo_import /var/lib/postgresql/9.4/main/private.key
-- lo_import 33583
-- postgres=# \lo_import /var/lib/postgresql/9.4/main/public.key
-- lo_import 33584

INSERT INTO keys VALUES ( pgp_key_id(lo_get(33583)) ,lo_get(33584), lo_get(33583));


-- Explicit way, less secure.
INSERT INTO keys VALUES
    ( pgp_key_id($$\x99032e0456c489fe1108009f62be739d0b30e215f73f1c7af6582739c4d9fa01aeef349344ff0351ea02f84f689c0c6a7f1c4efb5894ce91b3d330f472ae6969621767762edf0f804c1d5a306560daaeeb0f3b66a6229395e2e8a1fd8ab18798e50557b5ecc558992ca9a0ef209e9f62af438c04ea76c5b6fbe34d94e417dffd152c3752d559ef8969c1718e049e336ddb51e63c65a54e00abc9fede73d7e5f6e2302414d8ced6756ca45879bb22ab658f2b42c2232180ec17823ac41082144b87a4cf796ddad0808217b9369f1b0cd3c4de15ce90b730dff6d2214fc1804617a76ec37a9269563ccc59ed4419c6e0cde5bd3a9ea0e4e9e42a835704dd1d44d00eed1ecf5c7a275b70314b0100ad40ba1ff0c5b9e7731f8b99579203dd4210670b14c9fba1aeae8fcf8caf843707fb041ec34d981f9a88b78553ba6a059e30030f060b581168fda116ac0e79b4faea9986fb8739d4651ae407ba73f8da7ebd58080637fa07cda38ee24d020d3d5de0695179973e7d55c0eada48a9ba3990449eeb75a0019ab9ab8651c88711ab88a44b0a973c318f41a0fff8f7ede56500c43447277028c08001e889fc6df4be470df2d32cee80d153d228450a77094ef097e9a8e06904bcf5da9cd2f33f77cecc42521a9de4f5b4924caca54718e6808f8c680a08db51dab75780991883c5a3ecd3d4d598d4ea62fb66b24b5827f694d36deccdefbc82eafe5cdae0879bf0652960f72e0381c053273feef5c1f9409b416abbd2f8ac47bf54cb13fee9c022127fe407ff7317ed490f36b09d78c9e8d15c486058f66589c900b923fa986f5ac2322e690f0ec35d5d1d8084de2fdee1ae61cfe8fcf05fc0a62ed0166f1a0a55c18b8f73a3c2af6052a8d41a2a9fa2913ddb0005966285e9ff78ebeefabd9f30a2548e35de170d68fa445a6ba6785c82a3970a9943cc2ce704f1ba323cbf97fee914098f6e7fa07b44b81aa5d878ccc7d1a659015723ad3b5f406bc80ae427125be22c8c675eb2b14f1ab5f7778551b042ba186959ca7e60b5e6bcb6bc55225f3bdaeb93e4f5b82564227ef2b323ce99fe1eb4c55a1413e111d51a2ed7daed8e53988ea2525bb74307193ac9f50dceefeff88126b0f66bfb913d3bf6525df620f8fa4e80c0b43f456d616e75656c20285468697320697320612074657374206b657920666f7220616e2061727469636c6529203c63616c766f407079746869616e2e636f6d3e887a041311080022050256c489fe021b03060b090807030206150802090a0b0416020301021e01021780000a0910e9ceecf3e65ff517fa7e00ff6fbc2a78a3dd7d1682e6af5b576e9aed556d67ef5ca66bdebcd551c91a49b9c9010084a69d54f8cf5fbf87f32e190d3859cf761db35b3c983a4f9aa8b5a5645a2952b9020d0456c489fe100800c7e0dd9b3806f269745c6ae8ae0073450b825f9192e3838669a59a0cba44252dfc5dc0c9b9959ef933456bcf85dcf958ee5ebfb9d6dce9cd10c8d17797c739fc033425833e3a096cb3c35de0cbae50f7b71f563f7371ccf516d014d27c2ff070661fb7e5199946a1d2b5042708447abce70b4b0ac99cbda09f33fb243313ef911056175dbab4f937f96149e38a0349eee1ab3e62494cdc4bd91f62594c5acbd0a4f94bc869411f3da885f9392e3168fd70328be7e8f7df0abb7df08f83d73dcde3b2c44587994a5b0bda213e89f9eb434c14ee22cd91de4b0b5de4168900bef9fdc065083e58f6e2bf228195b08c77bcb1fad22484cde5664dff8dba2072e29700030507fd19d529288f45fd9cf6d2946b1f3207b5a88d9b1358725520f36ccad6c6b8d0568b4c7db39ba77c12c142a3c7e65cddece9bb1b5f9fd779eef5b70f4934b422dcfbacb683f0ab56537859cc51431287855b9bead02f46acff127b4096b7c0c3165f440dce9a9c4afd2eedfb13dda920d6cf05cce245e13456a7bb3cfb3f60b50ce7ca11689ea2874473636c969ecf87df3e377f0cc4e56158f5ee7ddaeaec4dbd1e7416d930f97203bf8cd2e348346eafdb5ecc2071f5b2d409b3787a95772d28d0c6d2ceedd3b7a79e658ca03c44b5c0f0168e69dbf5ff2b3e732167e6092a06b99c529f9cb104e0251bd4cc92a68800fed98a8fe3a656d9fbe7fcf5c9efb5238861041811080009050256c489fe021b0c000a0910e9ceecf3e65ff517f1f700fe2409e4471e908e73945d1ff6dcc79131050eb0be18cb0b4a474fccc39ee5d14b00fd114d37b1f132cccee1215765c29cabfb58fd0fb9d07b9e7e1abba106c10935f2$$::bytea),
      $$\x99032e0456c489fe1108009f62be739d0b30e215f73f1c7af6582739c4d9fa01aeef349344ff0351ea02f84f689c0c6a7f1c4efb5894ce91b3d330f472ae6969621767762edf0f804c1d5a306560daaeeb0f3b66a6229395e2e8a1fd8ab18798e50557b5ecc558992ca9a0ef209e9f62af438c04ea76c5b6fbe34d94e417dffd152c3752d559ef8969c1718e049e336ddb51e63c65a54e00abc9fede73d7e5f6e2302414d8ced6756ca45879bb22ab658f2b42c2232180ec17823ac41082144b87a4cf796ddad0808217b9369f1b0cd3c4de15ce90b730dff6d2214fc1804617a76ec37a9269563ccc59ed4419c6e0cde5bd3a9ea0e4e9e42a835704dd1d44d00eed1ecf5c7a275b70314b0100ad40ba1ff0c5b9e7731f8b99579203dd4210670b14c9fba1aeae8fcf8caf843707fb041ec34d981f9a88b78553ba6a059e30030f060b581168fda116ac0e79b4faea9986fb8739d4651ae407ba73f8da7ebd58080637fa07cda38ee24d020d3d5de0695179973e7d55c0eada48a9ba3990449eeb75a0019ab9ab8651c88711ab88a44b0a973c318f41a0fff8f7ede56500c43447277028c08001e889fc6df4be470df2d32cee80d153d228450a77094ef097e9a8e06904bcf5da9cd2f33f77cecc42521a9de4f5b4924caca54718e6808f8c680a08db51dab75780991883c5a3ecd3d4d598d4ea62fb66b24b5827f694d36deccdefbc82eafe5cdae0879bf0652960f72e0381c053273feef5c1f9409b416abbd2f8ac47bf54cb13fee9c022127fe407ff7317ed490f36b09d78c9e8d15c486058f66589c900b923fa986f5ac2322e690f0ec35d5d1d8084de2fdee1ae61cfe8fcf05fc0a62ed0166f1a0a55c18b8f73a3c2af6052a8d41a2a9fa2913ddb0005966285e9ff78ebeefabd9f30a2548e35de170d68fa445a6ba6785c82a3970a9943cc2ce704f1ba323cbf97fee914098f6e7fa07b44b81aa5d878ccc7d1a659015723ad3b5f406bc80ae427125be22c8c675eb2b14f1ab5f7778551b042ba186959ca7e60b5e6bcb6bc55225f3bdaeb93e4f5b82564227ef2b323ce99fe1eb4c55a1413e111d51a2ed7daed8e53988ea2525bb74307193ac9f50dceefeff88126b0f66bfb913d3bf6525df620f8fa4e80c0b43f456d616e75656c20285468697320697320612074657374206b657920666f7220616e2061727469636c6529203c63616c766f407079746869616e2e636f6d3e887a041311080022050256c489fe021b03060b090807030206150802090a0b0416020301021e01021780000a0910e9ceecf3e65ff517fa7e00ff6fbc2a78a3dd7d1682e6af5b576e9aed556d67ef5ca66bdebcd551c91a49b9c9010084a69d54f8cf5fbf87f32e190d3859cf761db35b3c983a4f9aa8b5a5645a2952b9020d0456c489fe100800c7e0dd9b3806f269745c6ae8ae0073450b825f9192e3838669a59a0cba44252dfc5dc0c9b9959ef933456bcf85dcf958ee5ebfb9d6dce9cd10c8d17797c739fc033425833e3a096cb3c35de0cbae50f7b71f563f7371ccf516d014d27c2ff070661fb7e5199946a1d2b5042708447abce70b4b0ac99cbda09f33fb243313ef911056175dbab4f937f96149e38a0349eee1ab3e62494cdc4bd91f62594c5acbd0a4f94bc869411f3da885f9392e3168fd70328be7e8f7df0abb7df08f83d73dcde3b2c44587994a5b0bda213e89f9eb434c14ee22cd91de4b0b5de4168900bef9fdc065083e58f6e2bf228195b08c77bcb1fad22484cde5664dff8dba2072e29700030507fd19d529288f45fd9cf6d2946b1f3207b5a88d9b1358725520f36ccad6c6b8d0568b4c7db39ba77c12c142a3c7e65cddece9bb1b5f9fd779eef5b70f4934b422dcfbacb683f0ab56537859cc51431287855b9bead02f46acff127b4096b7c0c3165f440dce9a9c4afd2eedfb13dda920d6cf05cce245e13456a7bb3cfb3f60b50ce7ca11689ea2874473636c969ecf87df3e377f0cc4e56158f5ee7ddaeaec4dbd1e7416d930f97203bf8cd2e348346eafdb5ecc2071f5b2d409b3787a95772d28d0c6d2ceedd3b7a79e658ca03c44b5c0f0168e69dbf5ff2b3e732167e6092a06b99c529f9cb104e0251bd4cc92a68800fed98a8fe3a656d9fbe7fcf5c9efb5238861041811080009050256c489fe021b0c000a0910e9ceecf3e65ff517f1f700fe2409e4471e908e73945d1ff6dcc79131050eb0be18cb0b4a474fccc39ee5d14b00fd114d37b1f132cccee1215765c29cabfb58fd0fb9d07b9e7e1abba106c10935f2$$::bytea,
      $$\x9503530456c489fe1108009f62be739d0b30e215f73f1c7af6582739c4d9fa01aeef349344ff0351ea02f84f689c0c6a7f1c4efb5894ce91b3d330f472ae6969621767762edf0f804c1d5a306560daaeeb0f3b66a6229395e2e8a1fd8ab18798e50557b5ecc558992ca9a0ef209e9f62af438c04ea76c5b6fbe34d94e417dffd152c3752d559ef8969c1718e049e336ddb51e63c65a54e00abc9fede73d7e5f6e2302414d8ced6756ca45879bb22ab658f2b42c2232180ec17823ac41082144b87a4cf796ddad0808217b9369f1b0cd3c4de15ce90b730dff6d2214fc1804617a76ec37a9269563ccc59ed4419c6e0cde5bd3a9ea0e4e9e42a835704dd1d44d00eed1ecf5c7a275b70314b0100ad40ba1ff0c5b9e7731f8b99579203dd4210670b14c9fba1aeae8fcf8caf843707fb041ec34d981f9a88b78553ba6a059e30030f060b581168fda116ac0e79b4faea9986fb8739d4651ae407ba73f8da7ebd58080637fa07cda38ee24d020d3d5de0695179973e7d55c0eada48a9ba3990449eeb75a0019ab9ab8651c88711ab88a44b0a973c318f41a0fff8f7ede56500c43447277028c08001e889fc6df4be470df2d32cee80d153d228450a77094ef097e9a8e06904bcf5da9cd2f33f77cecc42521a9de4f5b4924caca54718e6808f8c680a08db51dab75780991883c5a3ecd3d4d598d4ea62fb66b24b5827f694d36deccdefbc82eafe5cdae0879bf0652960f72e0381c053273feef5c1f9409b416abbd2f8ac47bf54cb13fee9c022127fe407ff7317ed490f36b09d78c9e8d15c486058f66589c900b923fa986f5ac2322e690f0ec35d5d1d8084de2fdee1ae61cfe8fcf05fc0a62ed0166f1a0a55c18b8f73a3c2af6052a8d41a2a9fa2913ddb0005966285e9ff78ebeefabd9f30a2548e35de170d68fa445a6ba6785c82a3970a9943cc2ce704f1ba323cbf97fee914098f6e7fa07b44b81aa5d878ccc7d1a659015723ad3b5f406bc80ae427125be22c8c675eb2b14f1ab5f7778551b042ba186959ca7e60b5e6bcb6bc55225f3bdaeb93e4f5b82564227ef2b323ce99fe1eb4c55a1413e111d51a2ed7daed8e53988ea2525bb74307193ac9f50dceefeff88126b0f66bfb913d3bf6525df620f8fa4e80c00000ff49f1c60c5aa28856235229b270c337e2cd9471c26f9362c60297424313d9eb46107ab43f456d616e75656c20285468697320697320612074657374206b657920666f7220616e2061727469636c6529203c63616c766f407079746869616e2e636f6d3e887a041311080022050256c489fe021b03060b090807030206150802090a0b0416020301021e01021780000a0910e9ceecf3e65ff517fa7e00ff6fbc2a78a3dd7d1682e6af5b576e9aed556d67ef5ca66bdebcd551c91a49b9c9010084a69d54f8cf5fbf87f32e190d3859cf761db35b3c983a4f9aa8b5a5645a29529d023d0456c489fe100800c7e0dd9b3806f269745c6ae8ae0073450b825f9192e3838669a59a0cba44252dfc5dc0c9b9959ef933456bcf85dcf958ee5ebfb9d6dce9cd10c8d17797c739fc033425833e3a096cb3c35de0cbae50f7b71f563f7371ccf516d014d27c2ff070661fb7e5199946a1d2b5042708447abce70b4b0ac99cbda09f33fb243313ef911056175dbab4f937f96149e38a0349eee1ab3e62494cdc4bd91f62594c5acbd0a4f94bc869411f3da885f9392e3168fd70328be7e8f7df0abb7df08f83d73dcde3b2c44587994a5b0bda213e89f9eb434c14ee22cd91de4b0b5de4168900bef9fdc065083e58f6e2bf228195b08c77bcb1fad22484cde5664dff8dba2072e29700030507fd19d529288f45fd9cf6d2946b1f3207b5a88d9b1358725520f36ccad6c6b8d0568b4c7db39ba77c12c142a3c7e65cddece9bb1b5f9fd779eef5b70f4934b422dcfbacb683f0ab56537859cc51431287855b9bead02f46acff127b4096b7c0c3165f440dce9a9c4afd2eedfb13dda920d6cf05cce245e13456a7bb3cfb3f60b50ce7ca11689ea2874473636c969ecf87df3e377f0cc4e56158f5ee7ddaeaec4dbd1e7416d930f97203bf8cd2e348346eafdb5ecc2071f5b2d409b3787a95772d28d0c6d2ceedd3b7a79e658ca03c44b5c0f0168e69dbf5ff2b3e732167e6092a06b99c529f9cb104e0251bd4cc92a68800fed98a8fe3a656d9fbe7fcf5c9efb52300015101cddfb1b3683f74b367659209d34282da3a384e70d4c17e68b82f26e031a579f944ec6089e870c5ce54a216e38861041811080009050256c489fe021b0c000a0910e9ceecf3e65ff517f1f700fe36668ecf6f95d873d3874e1d1c1e43446a0ddd1863d04ca8391cd70ad23e0f9300ff422ba4950db06c6416e902955d113c32d66c9cec96ecebc459591fa61ccc0c68$$::bytea
 );

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

-- END preparing environment

-- BEGIN local structures

CREATE SEQUENCE global_seq INCREMENT BY 1 MINVALUE 1 NO MAXVALUE;

---

CREATE TABLE local_search (
  id bigint PRIMARY KEY,
  _FTS tsvector
);

CREATE INDEX fts_index ON local_search USING GIST(_FTS);

-- Having this, you avoid to have a column with a constant value in the table,
-- consuming unnecessary space. You can have with this method, different names
-- and tables accross the cluster, but always using the same query against `local_search`
CREATE TABLE local_search_host1 () INHERITS (local_search);
CREATE INDEX fts_index_host1 ON local_search_host1 USING GIST(_FTS);

-- A better idea could be simulating routing as Elastic Search. That is, the
-- child table can hold one of the filters as the table name. For searching, you
-- will always point to the parent table, allowing you to go through to split
-- data locally for targeted search OR full search.

CREATE TABLE local_search_host1 (INHERITS local_search);
CREATE INDEX fts_index_host1 ON local_search_host1 USING GIST(_FTS);

-- Example:
-- fts_proxy=# select id from local_search where to_tsquery('Asthma | Athetosis') @@ _fts;
-- id returned 20

---

CREATE TABLE __person__pgp_map
     (
      source varchar(8),
      keyid varchar(16),
      ssn bigint,
      fname text,
      lname text,
      description text,
      auth_drugs text[], -- This is an encrypted text vector
      patology text
    );

-- create table __person__map_pgp (INHERITS __person__map);

-- CREATE TABLE __person__pgp
--      (
--      id bigint PRIMARY KEY,
--      partial_ssn varchar(4), -- Non encrypted field for other fast search purposes
--      ssn bytea,
--      keyid varchar(16), -- REFERENCES keys,
--      fname bytea,
--      lname bytea,
--      description bytea,
--      auth_drugs bytea, -- This is an encrypted text vector
--      patology bytea
-- );


CREATE OR REPLACE FUNCTION _func_get_FTS_encrypt_and_push_to_RDS() RETURNS "trigger" AS $$
DECLARE
        secret bytea;
        RDS_MAP __person__pgp_RDS%ROWTYPE;
        FTS_MAP local_search%ROWTYPE;
BEGIN

    SELECT pub INTO secret FROM keys WHERE keyid = NEW.keyid;

    RDS_MAP.source := NEW.source;
    -- FTS_MAP.source := NEW.source;
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
    -- Both tables contain same id,source
    INSERT INTO __person__pgp_RDS SELECT (RDS_MAP.*);
    EXECUTE 'INSERT INTO local_search_' || NEW.source || ' SELECT (' ||  quote_literal(FTS_MAP) || '::local_search).* ';
    -- INSERT INTO local_search SELECT (FTS_MAP.*);
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
      'host1',  -- source: host1
                -- You can do this better by grabbing this data from a persistent
                -- location
      '76CDA76B5C1EA9AB',
       round(random()*1000000000),
      ('{Romulo,Ricardo,Romina,Fabricio,Francisca,Noa,Laura,Priscila,Tiziana,Ana,Horacio,Tim,Mario}'::text[])[round(random()*12+1)],
      ('{Perez,Ortigoza,Tucci,Smith,Fernandez,Samuel,Veloso,Guevara,Calvo,Cantina,Casas,Korn,Rodriguez,Ike,Baldo,Vespi}'::text[])[round(random()*15+1)],
      ('{some,random,text,goes,here}'::text[])[round(random()*5+1)] ,
      get_drugs_random(round(random()*10)::int),
      ('{Anotia,Appendicitis,Apraxia,Argyria,Arthritis,Asthma,Astigmatism,Atherosclerosis,Athetosis,Atrophy,Abscess,Influenza,Melanoma}'::text[])[round(random()*12+1)]
      FROM generate_series(1,50) ;

-- Complete test:

-- Limiting the matches
SELECT rds.source, convert_from(pgp_pub_decrypt(ssn::text::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name)
FROM __person__pgp_rds as rds JOIN
      keys ks USING (keyid)
WHERE rds.id IN (
                select id
                from local_search
                where to_tsquery('Asthma | Athetosis') @@ _fts LIMIT 5);


SELECT rds.source, convert_from(pgp_pub_decrypt(ssn::text::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name)
FROM __person__pgp_rds as rds JOIN
      keys ks USING (keyid)
WHERE rds.id IN (
                select id
                from local_search
                where to_tsquery('Asthma | Athetosis') @@ _fts LIMIT 5)
  AND rds.source = 'host1';


-- All the matches and double check from were the data came from.
SELECT ls.tableoid::regclass, rds.source,
       convert_from(pgp_pub_decrypt(ssn::text::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name)
FROM local_search ls JOIN
     __person__pgp_rds as rds USING (id),
     keys ks
WHERE to_tsquery('Asthma | Athetosis') @@ ls._fts;

-- tableoid      | source | convert_from
--------------------+--------+--------------
-- local_search_host1 | host1  | 563588056
-- (1 row)

-- With ranking


  SELECT rds.id,
  convert_from(pgp_pub_decrypt(fname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
  convert_from(pgp_pub_decrypt(lname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
  ts_rank( ls._FTS, query ) as rank
    FROM local_search ls JOIN
         __person__pgp_rds as rds ON (rds.id = ls.id AND rds.source = 'host1') JOIN
         keys ks USING (keyid),
         to_tsquery('Mario | Casas | (Casas:*A & Mario:*B) ') query
    WHERE
        ls._FTS  @@ query
    ORDER BY rank DESC;


convert_from(pgp_pub_decrypt(ssn::text::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name)
