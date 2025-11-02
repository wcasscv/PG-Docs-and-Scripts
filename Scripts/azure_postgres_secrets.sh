
#!/bin/bash
# Store PostgreSQL credentials in Azure Key Vault

az keyvault create --name MyKeyVault --resource-group MyResourceGroup --location eastus

az keyvault secret set --vault-name MyKeyVault --name PostgresUser --value "dbuser"
az keyvault secret set --vault-name MyKeyVault --name PostgresPassword --value "securePass123"
az keyvault secret set --vault-name MyKeyVault --name PostgresHost --value "db.example.com"
