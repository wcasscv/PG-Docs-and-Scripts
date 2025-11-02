
#!/bin/bash
# Store PostgreSQL credentials in GCP Secret Manager

gcloud secrets create myPostgresSecret --replication-policy="automatic"

echo -n '{"username":"dbuser","password":"securePass123","host":"db.example.com","port":5432,"dbname":"mydb"}' | \
gcloud secrets versions add myPostgresSecret --data-file=-
