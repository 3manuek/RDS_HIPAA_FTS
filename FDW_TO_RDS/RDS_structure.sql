

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
