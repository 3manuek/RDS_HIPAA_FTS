

CREATE SCHEMA enc_schema;

SET search_path TO enc_schema;

-- Encrpting locally, that's why we don't need to reference the key here.
create table enc_schema.__person__pgp
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
      patology bytea,
      PRIMARY KEY(id,source)
);

CREATE INDEX ON enc_schema.__person__pgp (partial_ssn);

-- TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME;
-- current_schema() || '.' ||
CREATE OR REPLACE FUNCTION basic_ins_trig() RETURNS trigger LANGUAGE plpgsql AS $basic_ins_trig$
DECLARE
  compTable text :=  TG_RELID::regclass::text ;
  childTable text := compTable || '_' || NEW.source ;
  statement text :=  'INSERT INTO ' || childTable || ' SELECT (' || QUOTE_LITERAL(NEW) || '::'  || compTable ||  ').*' ;
  createStmt text := 'CREATE TABLE ' || childTable  ||
    '(CHECK (source =' || quote_literal(NEW.source) || ')) INHERITS (' || compTable || ')';
  indexAdd1 text := 'CREATE INDEX ON ' || childTable || '(source,id)' ;
  indexAdd2 text := 'CREATE INDEX ON ' || childTable || '(source,ssn)' ;
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION
    WHEN undefined_table THEN
      EXECUTE createStmt;
      EXECUTE indexAdd1;
      EXECUTE indexAdd2;
      EXECUTE statement;
  END;
  RETURN NULL;

END;

$basic_ins_trig$;


CREATE TRIGGER part_person_pgp BEFORE INSERT ON __person__pgp
FOR EACH ROW EXECUTE PROCEDURE basic_ins_trig() ;
