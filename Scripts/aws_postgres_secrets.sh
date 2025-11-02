
#!/bin/bash
# Store PostgreSQL credentials in AWS Secrets Manager

aws secretsmanager create-secret \
  --name myPostgresSecret \
  --description "PostgreSQL credentials for app" \
  --secret-string '{"username":"dbuser","password":"securePass123","host":"db.example.com","port":5432,"dbname":"mydb"}'
