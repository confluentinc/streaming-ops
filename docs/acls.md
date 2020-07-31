# acls required to start

Wait, this might not be required...

```
ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation CREATE --topic '*' 
ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation WRITE --topic '*' 
ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation READ --topic '*' 
ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation DESCRIBE --topic '*' 
ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation DESCRIBE_CONFIGS --topic '*' 

ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation READ --consumer-group '*' 
ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation WRITE --consumer-group '*' 
ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation CREATE --consumer-group '*' 

ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation DESCRIBE --transactional-id '*' 
ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation WRITE --transactional-id '*' 

ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation IDEMPOTENT-WRITE --cluster-scope 
```

