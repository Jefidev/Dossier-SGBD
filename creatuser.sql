CREATE USER cb IDENTIFIED BY cb
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
PROFILE DEFAULT ACCOUNT UNLOCK;
GRANT CONNECT TO cb;
GRANT RESOURCE TO cb;
GRANT EXECUTE ON SYS.DBMS_LOCK TO cb;
ALTER USER cb QUOTA 5M ON USERS;

CREATE USER cbb IDENTIFIED BY cbb
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
PROFILE DEFAULT ACCOUNT UNLOCK;
GRANT CONNECT TO cbb;
GRANT RESOURCE TO cbb;
GRANT EXECUTE ON SYS.DBMS_LOCK TO cbb;
ALTER USER cbb QUOTA 5M ON USERS;

