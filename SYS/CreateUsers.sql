
DROP USER CB CASCADE;
DROP USER CBB CASCADE;
DROP USER CC CASCADE;
DROP ROLE CBROLE;


CREATE ROLE CBROLE NOT IDENTIFIED;
GRANT ALTER SESSION TO CBROLE;
GRANT CREATE DATABASE LINK TO CBROLE;
GRANT CREATE SESSION TO CBROLE;
GRANT CREATE PROCEDURE TO CBROLE;
GRANT CREATE SEQUENCE TO CBROLE;
GRANT CREATE TABLE TO CBROLE;
GRANT CREATE TRIGGER TO CBROLE;
GRANT CREATE TYPE TO CBROLE;
GRANT CREATE SYNONYM TO CBROLE;
GRANT CREATE VIEW TO CBROLE;
GRANT CREATE JOB TO CBROLE;
GRANT CREATE MATERIALIZED VIEW TO CBROLE;
GRANT CREATE ANY DIRECTORY TO CBROLE;
GRANT EXECUTE ON SYS.UTL_FILE TO CBROLE;
GRANT EXECUTE ON SYS.DBMS_LOCK TO CBROLE;
GRANT EXECUTE ON SYS.OWA_OPT_LOCK TO CBROLE;


CREATE USER CB IDENTIFIED BY CB DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP PROFILE DEFAULT ACCOUNT UNLOCK;
ALTER USER CB QUOTA UNLIMITED ON USERS;
GRANT CBROLE TO CB;

CREATE USER CBB IDENTIFIED BY CBB DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP PROFILE DEFAULT ACCOUNT UNLOCK;
ALTER USER CBB QUOTA UNLIMITED ON USERS;
GRANT CBROLE TO CBB;

CREATE USER CC IDENTIFIED BY CC DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP PROFILE DEFAULT ACCOUNT UNLOCK;
ALTER USER CC QUOTA UNLIMITED ON USERS;
GRANT CBROLE TO CC;

GRANT EXECUTE ON SYS.UTL_HTTP TO CB;
GRANT EXECUTE ON SYS.UTL_HTTP TO CBB;

CREATE OR REPLACE DIRECTORY MOVIEDIRECTORY AS 'C:\\MOVIEDIRECTORY';

GRANT READ, WRITE ON DIRECTORY MOVIEDIRECTORY TO CBB;
GRANT READ, WRITE ON DIRECTORY MOVIEDIRECTORY TO CB;
GRANT READ, WRITE ON DIRECTORY MOVIEDIRECTORY TO CC;

EXIT;
