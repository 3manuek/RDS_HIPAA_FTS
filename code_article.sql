-- DDL and data

CREATE EXTENSION pgcrypto;

-- Do this manually


CREATE TABLE keys (
  keyid varchar(8) PRIMARY KEY,
  pub bytea,
  priv bytea
);


-- dbtest=> \lo_import '/home/emanuel/dummyKeys/public.key' pubk
-- lo_import 16438
-- dbtest=> \lo_import '/home/emanuel/dummyKeys/private.key' privk
-- lo_import 16439


-- INSERT INTO keys VALUES ('E65FF517', pg_read_binary_file('public.key'),pg_read_binary_file('private.key'));
INSERT INTO keys ( pgp_key_id(lo_get(16430)) ,lo_get(16430), log_get(16437))

-- Straigthforward to apply

DROP TABLE __person__;
DROP TABLE __person__map;
DROP TABLE __person__pgp;

-- TODO
-- Add indexable columns like region, store , etc.

create table __person__
  (id serial PRIMARY KEY,
   fname bytea,
   lname bytea,
   description bytea,
   auth_drugs bytea, -- This is an encrypted text vector
   patology bytea,
   _FTS bytea -- this is the column storing the encrypted tsvector
   );

create table __person__pgp
     (id serial PRIMARY KEY,
      fname bytea,
      lname bytea,
      description bytea,
      auth_drugs bytea, -- This is an encrypted text vector
      patology bytea,
      _FTS bytea -- this is the column storing the encrypted tsvector
);

-- TODO:
-- table map remove _FTS field, add keyid.
-- doing that, now the trigger can select which key use for each row
-- You can also, set a key per table basis instead row based.


create table __person__map
     (fname text,
      lname text,
      description text,
      auth_drugs text[], -- This is an encrypted text vector
      patology text,
      _FTS text -- this is the column storing the encrypted tsvector
);


-- Test key ids
SELECT pgp_key_id(pub) from keys;

CREATE OR REPLACE FUNCTION get_drugs_random(int)
       RETURNS text[] AS
      $BODY$
      SELECT array_agg(p.drug) FROM (
        SELECT t.b FROM regexp_split_to_table(
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
      Zoloft', '\n') t(b)
ORDER BY random() LIMIT $1
) p(drug);
$BODY$
LANGUAGE 'sql' VOLATILE;

-- Initialize the sequence as RDS doesn't like to start it inside tx

SELECT nextval('__person___id_seq'::regclass);

CREATE OR REPLACE FUNCTION _func_name_FTS_insert() RETURNS "trigger" AS $$
DECLARE
        secret __person__._FTS%TYPE;
        NEW_MAP __person__%ROWTYPE;
        method text := 'aes';
        conv name := 'SQL_ASCII';
        parsedDrugs text;
BEGIN
        secret := NEW._FTS::bytea; -- Here you are, we take the secret, then we step over it.

        NEW_MAP._FTS := encrypt(
                          (setweight(to_tsvector(NEW.fname) , 'B' ) ||
                           setweight(to_tsvector(NEW.lname), 'A') ||
                           setweight(to_tsvector(NEW.description), 'C') ||
                           setweight(to_tsvector(NEW.auth_drugs::text), 'C') ||
                           setweight(to_tsvector(NEW.patology), 'D')
                          )::text::bytea, secret,method) ;
        -- Now we encrypt the rest of the columns
        NEW_MAP.fname := encrypt(NEW.fname::bytea, secret,method);
        NEW_MAP.lname := encrypt(NEW.lname::bytea, secret,method);
        NEW_MAP.auth_drugs := encrypt(NEW.auth_drugs::text::bytea, secret,method);
        NEW_MAP.description := encrypt(NEW.description::bytea, secret,method);
        NEW_MAP.patology := encrypt(NEW.patology::bytea, secret,method);
        NEW_MAP.id := nextval('__person___id_seq'::regclass);

        INSERT INTO __person__ SELECT (NEW_MAP.*);
   RETURN NULL;
END;
$$
LANGUAGE plpgsql;


-- CREATE TRIGGER trigger_befInsRow_name_FTS
-- BEFORE INSERT ON __person__map
-- FOR EACH ROW
-- EXECUTE PROCEDURE _func_name_FTS_insert();


-- Using PGP
-- pgp_pub_encrypt(data text, key bytea [, options text ]) returns bytea
-- pgp_pub_decrypt(msg bytea, key bytea [, psw text [, options text ]]) returns text

CREATE OR REPLACE FUNCTION _func_name_FTS_insert_pgp() RETURNS "trigger" AS $$
DECLARE
        -- secret __person__._FTS%TYPE;
        secret bytea;
        NEW_MAP __person__PGP%ROWTYPE;
        method text := 'aes';
        conv name := 'SQL_ASCII';
        parsedDrugs text;
BEGIN
        -- secret := NEW._FTS::bytea; -- Here you are, we take the secret, then we step over it.
        SELECT pub INTO secret FROM keys WHERE keyid = '76CDA76B5C1EA9AB';

        NEW_MAP._FTS := pgp_pub_encrypt(
                          (setweight(to_tsvector(NEW.fname) , 'B' ) ||
                           setweight(to_tsvector(NEW.lname), 'A') ||
                           setweight(to_tsvector(NEW.description), 'C') ||
                           setweight(to_tsvector(NEW.auth_drugs::text), 'C') ||
                           setweight(to_tsvector(NEW.patology), 'D')
                         )::text, secret) ;
        NEW_MAP.fname := pgp_pub_encrypt(NEW.fname, secret);
        -- Now we encrypt the rest of the columns
        NEW_MAP.lname := pgp_pub_encrypt(NEW.lname, secret);
        NEW_MAP.auth_drugs := pgp_pub_encrypt(NEW.auth_drugs::text, secret);
        NEW_MAP.description := pgp_pub_encrypt(NEW.description, secret);
        NEW_MAP.patology := pgp_pub_encrypt(NEW.patology, secret);
        NEW_MAP.id := nextval('__person__pgp_id_seq'::regclass);

        INSERT INTO __person__pgp SELECT (NEW_MAP.*);
   RETURN NULL;
END;
$$
LANGUAGE plpgsql;

      -- Creating the trigger
CREATE TRIGGER trigger_befInsRow_name_FTS_PGP
BEFORE INSERT ON __person__map
FOR EACH ROW
EXECUTE PROCEDURE _func_name_FTS_insert_pgp();


TRUNCATE TABLE __person__;
TRUNCATE TABLE __person__PGP;

INSERT INTO __person__map
  SELECT
      ('{Romulo,Ricardo,Romina,Fabricio,Francisca,Noa,Laura,Priscila,Tiziana,Ana,Horacio,Tim,Mario}'::text[])[round(random()*12+1)],
      ('{Perez,Ortigoza,Tucci,Smith,Fernandez,Samuel,Veloso,Guevara,Calvo,Cantina,Casas,Korn,Rodriguez,Ike,Baldo,Vespi}'::text[])[round(random()*15+1)],
      ('{some,random,text,goes,here}'::text[])[round(random()*5+1)] ,
      get_drugs_random(round(random()*10)::int),
      ('{Anotia,Appendicitis,Apraxia,Argyria,Arthritis,Asthma,Astigmatism,Atherosclerosis,Athetosis,Atrophy,Abscess,Influenza,Melanoma}'::text[])[round(random()*12+1)],
      'secret' FROM generate_series(1,50) ;

-- Basic Test

select pgp_pub_decrypt(_FTS, priv,'') from __person__PGP, keys limit 1;

-- TODO:
-- Show trigram features, allowing to deal with mispellings and similarity
