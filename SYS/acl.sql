

BEGIN
  
  BEGIN
    DBMS_NETWORK_ACL_ADMIN.drop_acl('http.xml');
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('ACL not exist');
  END;

  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(acl         => 'http.xml',
                                    description => 'WWW ACL',
                                    principal   => 'CB',
                                    is_grant    => true,
                                    privilege   => 'resolve');
 
  DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl       => 'http.xml',
                                       principal => 'CB',
                                       is_grant  => true,
                                       privilege => 'connect');
 
  DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(acl  => 'http.xml',
                                    host => '*');
END;
/
COMMIT;
