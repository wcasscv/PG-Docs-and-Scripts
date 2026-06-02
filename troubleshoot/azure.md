# Azure: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can know Azure well and still freeze in an interview.

That freeze usually does not mean you lack experience. It means your knowledge is stored as real work: checking Activity Logs, reading deployment errors, tracing NSGs, reviewing IAM, testing DNS, inspecting private endpoints, checking VM extensions, debugging AKS, looking at metrics, and fixing production issues under pressure.

An interview is different. It asks you to turn that practical experience into clear, structured answers.

This kit is built for that moment.

It covers 30 common Azure issues interviewers ask about, with symptoms, causes, diagnosis steps, resolutions, and examples. It is written for engineers who understand cloud operations but want better interview language when the pressure is on.

When you freeze, start with this sentence:

> “I would first identify whether the issue is identity, networking, compute, storage, platform service configuration, deployment, permissions, DNS, private connectivity, monitoring, or cost. Then I would use Azure evidence — Activity Log, Resource Health, metrics, logs, effective routes, effective security rules, and diagnostic settings — before changing anything.”

That sounds like someone who can operate Azure safely.

---

## How to use this kit

For every Azure issue, use this structure:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A strong Azure interview answer usually includes:

1. What the user or system sees.
2. Which Azure service is involved.
3. Whether it is identity, network, compute, storage, platform, deployment, or policy related.
4. Which Azure tool you check first.
5. What evidence proves the cause.
6. What safe change you make.
7. How you verify the fix.

Example:

> “If an Azure VM cannot reach a database, I would not assume the database is down. I would check NSGs, effective routes, DNS resolution, private endpoint configuration, firewall rules, identity, and service health. I would test from the source subnet and use Network Watcher where possible.”

That is a production-grade answer.

---

# Top 30 Azure issues and resolutions

---

## 1. Azure role-based access control failure

### Interview freeze point

The interviewer asks:

> “A user says they cannot access an Azure resource. What do you check?”

Many candidates say “give them Owner,” which is a weak answer.

### Strong interview answer

> “I would check the exact action they are trying to perform, the scope of their role assignment, whether they are using the right tenant and subscription, whether group membership has propagated, and whether Azure Policy, deny assignments, Privileged Identity Management, or management group inheritance affects access.”

### Symptoms

- User gets `AuthorizationFailed`.
- User can see a resource but cannot modify it.
- User can manage one resource group but not another.
- CI/CD principal cannot deploy.
- Access worked yesterday but fails today.
- Portal and CLI show different subscription context.

### Diagnostic commands

Show current account:

```bash
az account show
```

List subscriptions:

```bash
az account list --output table
```

Set subscription:

```bash
az account set --subscription "<subscription-id>"
```

Check role assignments:

```bash
az role assignment list \
  --assignee "<user-or-sp-object-id>" \
  --all \
  --output table
```

Check role assignment at scope:

```bash
az role assignment list \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>" \
  --output table
```

### Common causes

- Wrong subscription selected.
- Role assigned at wrong scope.
- User is in wrong tenant.
- Group membership not propagated yet.
- Privileged Identity Management role not activated.
- Deny assignment exists.
- Azure Policy blocks operation.
- Service principal secret expired.
- Managed identity lacks required role.

### Example error

```text
The client has permission to perform action ... however, the current tenant is not authorized.
```

This may indicate tenant/subscription mismatch.

### Resolution

Assign least-privilege role at correct scope:

```bash
az role assignment create \
  --assignee "<principal-id>" \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>"
```

For read-only:

```bash
az role assignment create \
  --assignee "<principal-id>" \
  --role "Reader" \
  --scope "/subscriptions/<sub-id>"
```

### Interview caution

Avoid granting `Owner` casually. `Owner` includes permission to delegate access.

### Verify

```bash
az role assignment list \
  --assignee "<principal-id>" \
  --all \
  --output table
```

Then test the exact failed action.

### Takeaway summary

Azure access issues are about principal, role, scope, tenant, and policy. Fix the smallest required permission at the correct scope.

---

## 2. Azure Policy blocking deployments

### Interview freeze point

The template looks valid, but Azure rejects the deployment.

### Strong interview answer

> “If a deployment fails even though the template is syntactically valid, I would check Azure Policy. Policies can deny resources based on location, SKU, tags, public network access, naming, encryption, or allowed resource types. I would inspect the deployment error and policy assignment scope.”

### Symptoms

- Deployment fails with policy violation.
- Resource creation denied.
- Required tag missing.
- SKU or region not allowed.
- Public IP or public access blocked.
- Works in dev subscription but not prod.

### Diagnostic commands

List policy assignments:

```bash
az policy assignment list --output table
```

Check policy state for resource group:

```bash
az policy state list \
  --resource-group "<rg-name>" \
  --output table
```

Deployment error:

```bash
az deployment group show \
  --resource-group "<rg-name>" \
  --name "<deployment-name>"
```

### Example error

```text
Resource was disallowed by policy. Policy assignment: Allowed locations.
```

### Common causes

- Required tags missing.
- Region not in allowed list.
- SKU blocked.
- Public network access denied.
- Resource type not allowed.
- Diagnostic settings required.
- Encryption or private endpoint required.
- Policy assigned at management group level.

### Example Bicep with required tags

```bicep
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  tags: {
    environment: 'prod'
    owner: 'platform'
    costCenter: 'shared'
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
```

### Resolution

- Read policy violation details.
- Add required tags or settings.
- Use allowed region/SKU.
- Request policy exemption only when justified.
- Fix IaC modules to comply by default.

Create exemption only with governance approval:

```bash
az policy exemption create \
  --name "<exemption-name>" \
  --policy-assignment "<assignment-id>" \
  --scope "<scope>" \
  --exemption-category Waiver
```

### Takeaway summary

Azure Policy is an admission control system. A valid template can still be denied by governance rules.

---

## 3. Wrong subscription or tenant context

### Interview freeze point

A command works locally but deploys to the wrong place or cannot find resources.

### Strong interview answer

> “I would verify the active Azure account, tenant, and subscription before troubleshooting the resource itself. Many Azure mistakes happen because the CLI, PowerShell, portal, or pipeline is pointed at the wrong context.”

### Symptoms

- Resource group not found.
- Deployment goes to wrong subscription.
- Permissions look missing but are correct elsewhere.
- Portal shows resource but CLI does not.
- CI/CD deploys to dev instead of prod.

### Diagnostic commands

Azure CLI:

```bash
az account show --output table
az account list --output table
```

Set context:

```bash
az account set --subscription "<subscription-id>"
```

PowerShell:

```powershell
Get-AzContext
Set-AzContext -Subscription "<subscription-id>"
```

### Common causes

- Multiple tenants.
- Multiple subscriptions.
- CLI cached previous context.
- Pipeline variable points to wrong service connection.
- Portal directory switched.
- Service principal belongs to different tenant.
- Terraform provider subscription ID wrong.

### Resolution

Set explicit subscription in scripts:

```bash
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
```

Terraform provider example:

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
```

Pipeline safety:

```yaml
variables:
  azureSubscription: 'prod-service-connection'
  resourceGroupName: 'rg-prod-app'
```

### Prevention

- Use explicit subscription IDs.
- Print context in pipelines.
- Use separate service connections per environment.
- Require approvals for prod.
- Add naming conventions and tags.

### Takeaway summary

Always confirm context before diagnosing. Wrong tenant or subscription makes every other signal misleading.

---

## 4. Virtual machine cannot connect over SSH or RDP

### Interview freeze point

The VM is running, but you cannot connect.

### Strong interview answer

> “I would check whether the VM is running, whether it has a public or private path, NSG rules, effective security rules, route tables, firewall, Bastion, Just-in-Time access, guest OS firewall, and whether the correct credentials or SSH key are being used.”

### Symptoms

- SSH times out.
- RDP fails.
- Connection refused.
- VM is reachable internally but not externally.
- Azure Bastion works but public IP does not.
- NSG appears correct but effective rules deny traffic.

### Diagnostic commands

Check VM:

```bash
az vm get-instance-view \
  --resource-group "<rg>" \
  --name "<vm>" \
  --output table
```

Check NIC:

```bash
az vm show \
  --resource-group "<rg>" \
  --name "<vm>" \
  --show-details \
  --output table
```

Check effective NSG rules:

```bash
az network nic list-effective-nsg \
  --resource-group "<rg>" \
  --name "<nic-name>" \
  --output table
```

Use Network Watcher:

```bash
az network watcher test-connectivity \
  --source-resource "<source-resource-id>" \
  --dest-address "<vm-private-ip>" \
  --dest-port 22
```

### Common causes

- VM stopped or deallocated.
- No public IP.
- NSG blocks port 22 or 3389.
- Route table sends traffic elsewhere.
- Guest firewall blocks port.
- SSH daemon or RDP service stopped.
- Wrong username or SSH key.
- Public IP changed.
- Just-in-Time access not enabled.
- Network virtual appliance blocks traffic.

### Resolution: add NSG rule carefully

```bash
az network nsg rule create \
  --resource-group "<rg>" \
  --nsg-name "<nsg>" \
  --name AllowSSHFromOffice \
  --priority 100 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes "<office-ip>/32" \
  --destination-port-ranges 22
```

For RDP:

```bash
az network nsg rule create \
  --resource-group "<rg>" \
  --nsg-name "<nsg>" \
  --name AllowRDPFromOffice \
  --priority 110 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes "<office-ip>/32" \
  --destination-port-ranges 3389
```

### Interview caution

Do not open SSH or RDP to `0.0.0.0/0` in production. Prefer Bastion, VPN, private access, or Just-in-Time.

### Takeaway summary

VM connectivity is a path problem: source, route, NSG, firewall, service, and credentials.

---

## 5. Network Security Group rule not working

### Interview freeze point

The rule exists, but traffic is still blocked.

### Strong interview answer

> “I would check effective security rules, not just the NSG definition. NSGs can be applied to subnets and NICs, rules have priorities, default deny rules apply, and another NSG or route may affect traffic.”

### Symptoms

- NSG rule appears correct but traffic fails.
- Subnet NSG allows traffic but NIC NSG denies it.
- Rule priority issue.
- Wrong source or destination prefix.
- Wrong port or protocol.
- Application still unreachable.

### Diagnostic commands

List NSG rules:

```bash
az network nsg rule list \
  --resource-group "<rg>" \
  --nsg-name "<nsg>" \
  --output table
```

Check effective rules on NIC:

```bash
az network nic list-effective-nsg \
  --resource-group "<rg>" \
  --name "<nic-name>" \
  --output table
```

### Common causes

- Lower priority deny rule wins.
- NSG attached at both subnet and NIC.
- Wrong source IP.
- Wrong destination port.
- Wrong protocol TCP/UDP.
- Azure service tag misunderstood.
- Application not listening.
- OS firewall also blocks traffic.

### Example rule

```bash
az network nsg rule create \
  --resource-group rg-app \
  --nsg-name nsg-web \
  --name AllowHTTPS \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --destination-port-ranges 443
```

### Verify app is listening on VM

Linux:

```bash
sudo ss -tlnp
```

Windows PowerShell:

```powershell
netstat -ano
```

### Takeaway summary

Always check effective NSG rules. The defined rule is not always the rule that applies.

---

## 6. Route table or UDR misconfiguration

### Interview freeze point

Traffic leaves the subnet but never reaches the destination.

### Strong interview answer

> “I would check effective routes on the NIC, user-defined routes, forced tunneling, next hop type, peering routes, and whether an NVA or firewall is forwarding correctly. Routing issues often look like application outages.”

### Symptoms

- VM cannot reach internet.
- Private endpoint unreachable.
- Traffic to on-prem fails.
- Traffic goes through firewall unexpectedly.
- One subnet works, another fails.
- Asymmetric routing.

### Diagnostic commands

Effective routes:

```bash
az network nic show-effective-route-table \
  --resource-group "<rg>" \
  --name "<nic-name>" \
  --output table
```

Next hop test:

```bash
az network watcher show-next-hop \
  --resource-group "<rg>" \
  --vm "<vm-name>" \
  --source-ip "<source-private-ip>" \
  --dest-ip "<destination-ip>"
```

### Common causes

- Default route `0.0.0.0/0` forced to NVA.
- NVA not forwarding.
- Wrong next hop IP.
- Missing route back.
- Peering route not propagated.
- VPN/ExpressRoute route issue.
- Private endpoint DNS points to wrong IP.
- Firewall blocks traffic.

### Example UDR

```bash
az network route-table route create \
  --resource-group rg-network \
  --route-table-name rt-app \
  --name default-to-firewall \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.0.0.4
```

### Resolution

- Correct next hop.
- Add missing return route.
- Fix NVA forwarding.
- Fix firewall policy.
- Remove incorrect UDR.
- Check route propagation.

### Takeaway summary

Routing problems are diagnosed through effective routes and next hop testing, not guesses.

---

## 7. VNet peering connectivity failure

### Interview freeze point

Two VNets are peered, but resources cannot talk.

### Strong interview answer

> “I would confirm peering exists in both directions, address spaces do not overlap, network access is enabled, route tables do not override traffic incorrectly, NSGs allow traffic, and DNS resolves to the expected private IP.”

### Symptoms

- VM in VNet A cannot reach VM in VNet B.
- Peering says connected but traffic fails.
- DNS resolves public IP instead of private.
- Works one direction but not the other.
- On-prem traffic does not transit peering.

### Diagnostic commands

```bash
az network vnet peering list \
  --resource-group "<rg>" \
  --vnet-name "<vnet-name>" \
  --output table
```

Check effective routes:

```bash
az network nic show-effective-route-table \
  --resource-group "<rg>" \
  --name "<nic-name>" \
  --output table
```

### Common causes

- Peering missing on one side.
- Address spaces overlap.
- NSG blocks traffic.
- UDR sends traffic to NVA.
- Gateway transit not configured correctly.
- DNS still points public.
- Firewall blocks east-west traffic.

### Example peering

```bash
az network vnet peering create \
  --name vnet-a-to-vnet-b \
  --resource-group rg-a \
  --vnet-name vnet-a \
  --remote-vnet "/subscriptions/<sub-id>/resourceGroups/rg-b/providers/Microsoft.Network/virtualNetworks/vnet-b" \
  --allow-vnet-access
```

Create reverse peering too.

### Gateway transit note

If one VNet uses another VNet’s VPN/ExpressRoute gateway, configure gateway transit and remote gateway usage correctly.

### Takeaway summary

VNet peering is not magic routing for everything. Check both peerings, NSGs, UDRs, DNS, and gateway transit.

---

## 8. Private Endpoint DNS problem

### Interview freeze point

The private endpoint exists, but the app still connects to a public endpoint or cannot resolve the service.

### Strong interview answer

> “Private Endpoint issues are often DNS issues. I would check whether the service FQDN resolves to the private endpoint IP from the client network, whether the correct Private DNS Zone is linked to the VNet, and whether on-prem DNS forwards to Azure correctly.”

### Symptoms

- App cannot connect to storage, SQL, Key Vault, or App Service over private endpoint.
- DNS resolves public IP.
- Works from one VNet but not another.
- Private endpoint approved but connection fails.
- Public network disabled and app breaks.

### Diagnostic commands

From a VM in the VNet:

```bash
nslookup <account>.blob.core.windows.net
nslookup <vault-name>.vault.azure.net
```

List private DNS zones:

```bash
az network private-dns zone list --output table
```

List VNet links:

```bash
az network private-dns link vnet list \
  --resource-group "<rg>" \
  --zone-name "privatelink.blob.core.windows.net" \
  --output table
```

### Common causes

- Private DNS Zone missing.
- VNet not linked to Private DNS Zone.
- Wrong private DNS zone name.
- On-prem DNS not forwarding.
- Custom DNS server not resolving Azure private zones.
- Private endpoint not approved.
- Public network disabled before DNS fixed.
- Multiple private endpoints causing confusion.

### Example: link private DNS zone to VNet

```bash
az network private-dns link vnet create \
  --resource-group rg-network \
  --zone-name privatelink.blob.core.windows.net \
  --name link-app-vnet \
  --virtual-network app-vnet \
  --registration-enabled false
```

### Verify

Expected result:

```text
storageacct.privatelink.blob.core.windows.net
Address: 10.10.2.5
```

### Takeaway summary

Private Endpoint connectivity is usually DNS first, network second. The service FQDN must resolve to the private IP.

---

## 9. Azure DNS or custom DNS failure

### Interview freeze point

Network looks fine, but name resolution fails.

### Strong interview answer

> “I would test DNS from the source host, check VNet DNS settings, custom DNS servers, private DNS zone links, conditional forwarders, and whether the failing name is public, private, or hybrid.”

### Symptoms

- Hostname does not resolve.
- Private names resolve in one VNet but not another.
- On-prem clients cannot resolve Azure private endpoint.
- Azure VM cannot resolve on-prem names.
- App connects by IP but not name.

### Diagnostic commands

Linux:

```bash
nslookup myservice.internal
dig myservice.internal
cat /etc/resolv.conf
```

Windows:

```powershell
nslookup myservice.internal
ipconfig /all
Resolve-DnsName myservice.internal
```

Azure:

```bash
az network vnet show \
  --resource-group "<rg>" \
  --name "<vnet>" \
  --query "dhcpOptions.dnsServers"
```

### Common causes

- Wrong VNet DNS server settings.
- Custom DNS server down.
- Private DNS zone not linked.
- Conditional forwarder missing.
- DNS record missing.
- Split-horizon DNS confusion.
- VM needs restart or DHCP renew after DNS setting change.
- Firewall blocks DNS port 53.

### Resolution

Set VNet DNS servers:

```bash
az network vnet update \
  --resource-group rg-network \
  --name app-vnet \
  --dns-servers 10.0.0.10 10.0.0.11
```

Link private DNS zone:

```bash
az network private-dns link vnet create \
  --resource-group rg-dns \
  --zone-name private.contoso.com \
  --name app-vnet-link \
  --virtual-network app-vnet \
  --registration-enabled false
```

### Takeaway summary

DNS is part of the network path. Check where the client asks, what it resolves, and whether that IP is reachable.

---

## 10. Azure Load Balancer backend unhealthy

### Interview freeze point

The load balancer exists, but traffic does not reach the VM or service.

### Strong interview answer

> “I would check backend pool membership, health probe configuration, NSG rules, guest firewall, route tables, and whether the application is listening on the probe and data ports. Load balancers send traffic only to healthy backend instances.”

### Symptoms

- Public IP reachable but app unavailable.
- Load balancer backend shows unhealthy.
- Probe fails.
- Works directly on VM but not through LB.
- One backend receives no traffic.

### Diagnostic checks

- Backend pool contains correct NICs or IPs.
- Probe port is open.
- Probe path returns expected status for HTTP probes.
- NSG allows probe and traffic.
- App listens on target port.

### Example health probe

```bash
az network lb probe create \
  --resource-group rg-app \
  --lb-name app-lb \
  --name http-probe \
  --protocol Http \
  --port 80 \
  --path /health
```

### Example rule

```bash
az network lb rule create \
  --resource-group rg-app \
  --lb-name app-lb \
  --name http-rule \
  --protocol Tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --frontend-ip-name LoadBalancerFrontEnd \
  --backend-pool-name app-backend \
  --probe-name http-probe
```

### Common causes

- Probe path wrong.
- App listens on different port.
- NSG blocks health probe.
- Backend VM not in pool.
- Guest firewall blocks port.
- Route table sends return traffic incorrectly.
- App binds to localhost only.

### Verify on VM

```bash
curl http://localhost/health
sudo ss -tlnp
```

### Takeaway summary

Load balancer health depends on probe success. Fix backend health before debugging client traffic.

---

## 11. Application Gateway backend unhealthy

### Interview freeze point

Application Gateway has more moving parts than Load Balancer.

### Strong interview answer

> “I would check backend health details, listener, rule, backend pool, HTTP settings, probe path, host header, TLS certificate, NSG, UDR, and whether the backend accepts traffic from the Application Gateway subnet.”

### Symptoms

- Application Gateway returns 502.
- Backend health is unhealthy.
- TLS errors.
- Path-based routing sends to wrong backend.
- Backend works directly but not through gateway.

### Diagnostic commands

Show backend health:

```bash
az network application-gateway show-backend-health \
  --resource-group "<rg>" \
  --name "<appgw>"
```

### Common causes

- Probe path wrong.
- Host header mismatch.
- Backend certificate not trusted.
- Backend NSG blocks App Gateway subnet.
- Wrong backend port.
- HTTP settings mismatch.
- Backend redirects probe unexpectedly.
- DNS resolution issue for FQDN backend.
- WAF blocking traffic.

### Example probe

```bash
az network application-gateway probe create \
  --resource-group rg-app \
  --gateway-name appgw \
  --name api-probe \
  --protocol Http \
  --host api.internal.contoso.com \
  --path /health \
  --interval 30 \
  --timeout 30 \
  --threshold 3
```

### Resolution

- Fix probe path and host header.
- Allow App Gateway subnet to backend.
- Fix backend TLS certificate trust.
- Confirm backend port.
- Check WAF logs.
- Confirm DNS from App Gateway perspective.

### Takeaway summary

Application Gateway 502 usually means backend health, probe, host header, TLS, routing, or WAF issue.

---

## 12. Azure Storage access denied

### Interview freeze point

The storage account exists, but upload/download fails.

### Strong interview answer

> “I would check whether access is through keys, SAS, Azure AD/RBAC, managed identity, or private endpoint. Then I would verify firewall rules, public network access, role assignment, token scope, container permissions, and network path.”

### Symptoms

- `AuthorizationPermissionMismatch`
- `AuthenticationFailed`
- `PublicAccessNotPermitted`
- `This request is not authorized`
- Works from portal but not app.
- Works from one subnet but not another.

### Diagnostic commands

Check storage account network rules:

```bash
az storage account show \
  --resource-group "<rg>" \
  --name "<account>" \
  --query "networkRuleSet"
```

Check blob containers:

```bash
az storage container list \
  --account-name "<account>" \
  --auth-mode login \
  --output table
```

Check role assignments:

```bash
az role assignment list \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>" \
  --output table
```

### Common causes

- Missing `Storage Blob Data Contributor` role.
- User has management-plane role but not data-plane role.
- Storage firewall blocks client.
- Public network disabled.
- Private endpoint DNS wrong.
- SAS token expired or missing permission.
- Wrong account/container name.
- Key rotation broke app.

### Important distinction

`Contributor` on a storage account lets you manage the storage account, but does not automatically grant blob data access through Azure AD. Blob data access needs roles such as:

```text
Storage Blob Data Reader
Storage Blob Data Contributor
Storage Blob Data Owner
```

### Resolution: assign data-plane role

```bash
az role assignment create \
  --assignee "<principal-id>" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>"
```

### Takeaway summary

Storage access problems often mix management-plane permissions, data-plane permissions, firewall, and private endpoint DNS.

---

## 13. Azure Storage firewall or private endpoint issue

### Interview freeze point

Storage permissions are correct, but the network blocks access.

### Strong interview answer

> “If identity is correct but storage access fails, I would check storage firewall rules, public network access, trusted services, private endpoint status, DNS resolution, and whether the client is coming from an allowed subnet or private IP path.”

### Symptoms

- Access works from Azure portal but not app.
- Access works from one subnet but not another.
- Public access disabled.
- Private endpoint exists but app fails.
- Error mentions network rules.

### Diagnostic commands

```bash
az storage account show \
  --resource-group "<rg>" \
  --name "<account>" \
  --query "{publicNetworkAccess:publicNetworkAccess, networkRuleSet:networkRuleSet}"
```

Private endpoint connections:

```bash
az network private-endpoint-connection list \
  --name "<account>" \
  --resource-group "<rg>" \
  --type Microsoft.Storage/storageAccounts \
  --output table
```

DNS test:

```bash
nslookup <account>.blob.core.windows.net
```

### Common causes

- Client subnet not allowed.
- Private endpoint not approved.
- DNS resolves public IP.
- Private DNS zone not linked.
- Public network disabled before private path ready.
- Wrong subresource, such as blob vs file.
- On-prem DNS not forwarding private zone.

### Resolution: allow subnet

```bash
az storage account network-rule add \
  --resource-group "<rg>" \
  --account-name "<account>" \
  --vnet-name "<vnet>" \
  --subnet "<subnet>"
```

### Resolution: private endpoint DNS

Link zone:

```bash
az network private-dns link vnet create \
  --resource-group rg-dns \
  --zone-name privatelink.blob.core.windows.net \
  --name app-vnet-link \
  --virtual-network app-vnet \
  --registration-enabled false
```

### Takeaway summary

If storage identity is right but access fails, check network rules and private endpoint DNS.

---

## 14. Key Vault access failure

### Interview freeze point

The secret exists, but the app cannot read it.

### Strong interview answer

> “I would check whether the Key Vault uses RBAC or access policies, whether the identity has secret permissions, whether firewall or private endpoint blocks access, whether soft delete or purge protection affects operations, and whether the app is using the expected managed identity.”

### Symptoms

- App cannot read secret.
- `Forbidden`
- `Access denied`
- Works locally but not in App Service or VM.
- Secret exists but identity cannot access it.
- Network error when public access disabled.

### Diagnostic commands

Check Key Vault settings:

```bash
az keyvault show \
  --name "<vault-name>" \
  --query "{enableRbacAuthorization:properties.enableRbacAuthorization, publicNetworkAccess:properties.publicNetworkAccess}"
```

List role assignments:

```bash
az role assignment list \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>" \
  --output table
```

Get secret with current identity:

```bash
az keyvault secret show \
  --vault-name "<vault-name>" \
  --name "<secret-name>"
```

### Common causes

- Vault uses RBAC but access policy was configured, or the reverse.
- Managed identity not enabled.
- Wrong identity assigned.
- Missing `Key Vault Secrets User` role.
- Firewall blocks app.
- Private endpoint DNS wrong.
- Secret name typo.
- Secret disabled or expired.

### Resolution: assign RBAC role

```bash
az role assignment create \
  --assignee "<principal-id>" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
```

### App Service managed identity example

```bash
az webapp identity assign \
  --resource-group "<rg>" \
  --name "<app-name>"
```

### Takeaway summary

Key Vault access needs both identity permission and network path. Also confirm whether the vault uses RBAC or access policies.

---

## 15. Managed identity not working

### Interview freeze point

Managed identity avoids secrets, but only if the right identity has the right role.

### Strong interview answer

> “I would check whether system-assigned or user-assigned managed identity is enabled, whether the application is using the correct identity, whether the identity has the required Azure role, and whether token acquisition is targeting the correct resource.”

### Symptoms

- App cannot authenticate to Azure resource.
- Token request fails.
- Wrong identity used.
- Works locally with developer account but not in Azure.
- Managed identity exists but has no permissions.

### Diagnostic commands

For VM:

```bash
az vm identity show \
  --resource-group "<rg>" \
  --name "<vm>"
```

For App Service:

```bash
az webapp identity show \
  --resource-group "<rg>" \
  --name "<app>"
```

For role assignments:

```bash
az role assignment list \
  --assignee "<principal-id>" \
  --all \
  --output table
```

### Common causes

- Identity not enabled.
- Role assignment missing.
- Role assigned at wrong scope.
- User-assigned identity not attached.
- App code requests wrong client ID.
- Token audience/resource wrong.
- Propagation delay after role assignment.

### Resolution: enable identity

```bash
az webapp identity assign \
  --resource-group rg-app \
  --name app-prod
```

Assign access:

```bash
az role assignment create \
  --assignee "<principal-id>" \
  --role "Storage Blob Data Reader" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>"
```

### User-assigned identity note

If multiple identities exist, application code may need the client ID of the intended identity.

### Takeaway summary

Managed identity removes stored credentials, but it still needs correct attachment, token usage, role, and scope.

---

## 16. App Service deployment failure

### Interview freeze point

The code deploys but the web app does not start.

### Strong interview answer

> “I would separate deployment failure from runtime failure. I would check deployment logs, App Service logs, application settings, startup command, runtime stack, managed identity, networking, health checks, and whether the app can reach dependencies.”

### Symptoms

- Deployment succeeds but app returns 500.
- App Service returns 502 or 503.
- Container app fails to start.
- Slot swap fails.
- App settings missing.
- Startup timeout.

### Diagnostic commands

View logs:

```bash
az webapp log tail \
  --resource-group "<rg>" \
  --name "<app-name>"
```

Show app settings:

```bash
az webapp config appsettings list \
  --resource-group "<rg>" \
  --name "<app-name>" \
  --output table
```

Restart:

```bash
az webapp restart \
  --resource-group "<rg>" \
  --name "<app-name>"
```

### Common causes

- Missing environment variables.
- Wrong runtime stack.
- Startup command wrong.
- App listens on wrong port.
- Container image pull failure.
- Key Vault reference unresolved.
- Private dependency unreachable.
- App Service plan exhausted.
- Health check path wrong.
- Slot setting not marked sticky.

### Example app setting

```bash
az webapp config appsettings set \
  --resource-group rg-app \
  --name app-prod \
  --settings ASPNETCORE_ENVIRONMENT=Production
```

### Container port example

For Linux custom containers, app should listen on expected port or set:

```bash
az webapp config appsettings set \
  --resource-group rg-app \
  --name app-prod \
  --settings WEBSITES_PORT=8080
```

### Takeaway summary

App Service issues are often app configuration, runtime, startup, identity, port, or dependency connectivity.

---

## 17. App Service networking or VNet integration issue

### Interview freeze point

The app works publicly but cannot reach private resources.

### Strong interview answer

> “I would check whether regional VNet integration is enabled, whether the app is integrated with the correct subnet, whether route-all is needed, whether DNS points to private endpoints, and whether NSGs, UDRs, or firewalls allow traffic.”

### Symptoms

- App cannot reach private SQL, storage, or API.
- DNS resolves public endpoint instead of private.
- Works from VM in VNet but not App Service.
- Public access disabled and app breaks.
- Outbound IP not allowed.

### Diagnostic commands

Show VNet integration:

```bash
az webapp vnet-integration list \
  --resource-group "<rg>" \
  --name "<app-name>"
```

Show app settings:

```bash
az webapp config appsettings list \
  --resource-group "<rg>" \
  --name "<app-name>"
```

### Common causes

- VNet integration not enabled.
- Wrong subnet integrated.
- Private DNS zone not linked.
- App uses public DNS path.
- Storage/SQL firewall does not allow app path.
- Route-all not enabled where needed.
- NSG or UDR blocks outbound traffic.
- App Service Environment assumptions confused with standard App Service.

### Resolution: add VNet integration

```bash
az webapp vnet-integration add \
  --resource-group rg-app \
  --name app-prod \
  --vnet app-vnet \
  --subnet appservice-integration
```

Enable route all if required:

```bash
az webapp config appsettings set \
  --resource-group rg-app \
  --name app-prod \
  --settings WEBSITE_VNET_ROUTE_ALL=1
```

### Takeaway summary

App Service private connectivity depends on VNet integration, DNS, routing, and target firewall/private endpoint configuration.

---

## 18. Azure SQL connectivity failure

### Interview freeze point

The database is online, but the app cannot connect.

### Strong interview answer

> “I would check whether the failure is authentication, firewall, private endpoint DNS, connection string, TLS, server name, database name, or service health. Azure SQL also has server-level firewall and private endpoint considerations.”

### Symptoms

- Login timeout.
- Authentication failed.
- Cannot open server requested by login.
- Public network disabled.
- Works from developer machine but not app.
- App connects to wrong database.

### Diagnostic commands

Check SQL server firewall rules:

```bash
az sql server firewall-rule list \
  --resource-group "<rg>" \
  --server "<server-name>" \
  --output table
```

Check private endpoint connections:

```bash
az network private-endpoint-connection list \
  --name "<server-name>" \
  --resource-group "<rg>" \
  --type Microsoft.Sql/servers \
  --output table
```

DNS test:

```bash
nslookup <server-name>.database.windows.net
```

### Common causes

- Client IP not allowed.
- Public network disabled.
- Private endpoint DNS wrong.
- Wrong username/password.
- Managed identity not configured.
- SQL user missing.
- Connection string points wrong server.
- NSG/UDR blocks path.
- TLS/driver issue.

### Resolution: add firewall rule for controlled source

```bash
az sql server firewall-rule create \
  --resource-group rg-db \
  --server sql-prod \
  --name AllowOffice \
  --start-ip-address "<office-ip>" \
  --end-ip-address "<office-ip>"
```

### Managed identity access pattern

- Enable managed identity on app.
- Create Azure AD user in database.
- Grant database permissions.
- Use managed identity authentication in connection string/code.

### Takeaway summary

Azure SQL failures are usually firewall, private DNS, authentication, or connection string issues.

---

## 19. AKS pod networking failure

### Interview freeze point

Pods cannot talk to services, DNS, or external endpoints in AKS.

### Strong interview answer

> “I would check whether the issue is pod-to-pod, pod-to-service, pod-to-internet, or pod-to-private-resource. Then I would check CNI mode, NetworkPolicy, CoreDNS, NSGs, UDRs, node subnet routes, and Azure Firewall or NAT Gateway if used.”

### Symptoms

- Pods cannot reach internet.
- Pods cannot reach private endpoints.
- DNS failures.
- Service timeouts.
- Only certain namespaces fail.
- NetworkPolicy blocks traffic.

### Diagnostic commands

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get networkpolicy -A
kubectl -n kube-system get pods
kubectl -n kube-system logs -l k8s-app=kube-dns
```

Test from pod:

```bash
kubectl run net-test --rm -it --image=curlimages/curl -- sh
```

### Common causes

- NetworkPolicy denies traffic.
- CoreDNS unhealthy.
- UDR sends traffic to firewall without allow rule.
- SNAT exhaustion.
- NAT Gateway missing for outbound.
- Private endpoint DNS wrong.
- NSG blocks node subnet traffic.
- CNI IP exhaustion.
- Azure Firewall blocks FQDN or port.

### Resolution examples

Allow DNS in NetworkPolicy.
Fix private DNS zone links.
Add Azure Firewall allow rule.
Add NAT Gateway for scalable outbound.
Increase subnet size if pod IPs are exhausted.

### Takeaway summary

AKS network debugging starts by defining the path: pod to pod, service, DNS, internet, or private endpoint.

---

## 20. AKS cluster cannot schedule pods

### Interview freeze point

Pods are pending in AKS, but the issue could be Kubernetes or Azure capacity.

### Strong interview answer

> “I would check pod events, node capacity, requests, taints, node selectors, quotas, autoscaler status, node pool max count, subnet IP availability, and Azure regional capacity or quota.”

### Symptoms

- Pods Pending.
- Cluster autoscaler does not scale.
- Node pool at max.
- Insufficient CPU or memory.
- Subnet IP exhaustion.
- Pods require unavailable node labels or GPU.

### Diagnostic commands

```bash
kubectl describe pod <pod> -n <namespace>
kubectl get nodes
kubectl describe nodes
az aks show --resource-group "<rg>" --name "<aks>"
az aks nodepool list --resource-group "<rg>" --cluster-name "<aks>" --output table
```

### Common causes

- Requests too high.
- Node pool max reached.
- Azure quota reached.
- Subnet IP exhaustion with Azure CNI.
- Taints not tolerated.
- Node selector mismatch.
- GPU workload without GPU node pool.
- PodDisruptionBudget or topology constraints.

### Resolution

Scale node pool:

```bash
az aks nodepool scale \
  --resource-group rg-aks \
  --cluster-name aks-prod \
  --name nodepool1 \
  --node-count 5
```

Enable/update autoscaler:

```bash
az aks nodepool update \
  --resource-group rg-aks \
  --cluster-name aks-prod \
  --name nodepool1 \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10
```

### Takeaway summary

AKS scheduling failures may be Kubernetes scheduling rules or Azure node pool/subnet/quota limits.

---

## 21. AKS upgrade failure

### Interview freeze point

Upgrades fail because of node pools, PDBs, deprecated APIs, or capacity.

### Strong interview answer

> “Before upgrading AKS, I would check supported versions, deprecated APIs, node pool health, PodDisruptionBudgets, available capacity, add-ons, and workload readiness. If upgrade fails, I would inspect events, failed node pool operations, and Azure activity logs.”

### Symptoms

- AKS upgrade fails or stalls.
- Node pool upgrade does not complete.
- Pods cannot drain.
- Deprecated API warnings.
- Workload disruption during upgrade.

### Diagnostic commands

Check versions:

```bash
az aks get-upgrades \
  --resource-group "<rg>" \
  --name "<aks>" \
  --output table
```

Check PDBs:

```bash
kubectl get pdb -A
```

Check deprecated APIs with cluster tools where available.

### Common causes

- PDB prevents node drain.
- Insufficient spare capacity.
- Node pool quota/capacity issue.
- Deprecated API versions in manifests.
- Add-on incompatibility.
- Workloads with local storage.
- Custom admission webhook blocking changes.

### Resolution

- Fix deprecated API manifests.
- Ensure PDBs allow disruption.
- Add temporary capacity.
- Upgrade non-prod first.
- Upgrade node pools safely.
- Monitor rollout.

Upgrade:

```bash
az aks upgrade \
  --resource-group rg-aks \
  --name aks-prod \
  --kubernetes-version <version>
```

### Takeaway summary

AKS upgrades are production changes. Check API compatibility, node drain safety, capacity, and PDBs first.

---

## 22. Azure Container Registry pull failure

### Interview freeze point

AKS or App Service cannot pull from ACR.

### Strong interview answer

> “I would check image name and tag, ACR permissions, managed identity or service principal access, network restrictions, private endpoint DNS, and whether AKS is attached to the registry.”

### Symptoms

- `ImagePullBackOff`
- `unauthorized: authentication required`
- Image tag not found.
- Works locally but not AKS.
- ACR firewall blocks pull.

### Diagnostic commands

Check ACR:

```bash
az acr repository list --name "<acr-name>" --output table
az acr repository show-tags --name "<acr-name>" --repository "<repo>" --output table
```

Attach AKS to ACR:

```bash
az aks update \
  --resource-group "<rg>" \
  --name "<aks>" \
  --attach-acr "<acr-name>"
```

### Common causes

- AKS kubelet identity lacks `AcrPull`.
- Wrong image path.
- Wrong tag.
- ACR public access disabled.
- Private endpoint DNS missing.
- Firewall blocks node subnet.
- Image not pushed.

### Resolution: assign AcrPull

```bash
az role assignment create \
  --assignee "<kubelet-identity-client-id-or-principal-id>" \
  --role AcrPull \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr-name>"
```

### Example image

```yaml
image: myregistry.azurecr.io/api:1.2.3
```

### Takeaway summary

ACR pull failures are usually image naming, tag, identity permission, or registry network restrictions.

---

## 23. Azure DevOps pipeline deployment failure

### Interview freeze point

The IaC or app deployment works locally but fails in pipeline.

### Strong interview answer

> “I would compare local and pipeline identity, variables, service connection, subscription, agent network path, secret availability, tool versions, and deployment logs. Pipeline failures often come from context, permissions, or missing variables.”

### Symptoms

- Deployment works locally but fails in CI/CD.
- Service connection unauthorized.
- Variables missing.
- Terraform state access denied.
- Azure CLI task uses wrong subscription.
- Agent cannot reach private endpoint.

### Diagnostic steps

- Print Azure context.
- Check service connection.
- Check variable group permissions.
- Check pipeline environment approvals.
- Check tool versions.
- Check agent network.

### Example Azure DevOps CLI task

```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'prod-service-connection'
    scriptType: bash
    scriptLocation: inlineScript
    inlineScript: |
      az account show --output table
      az group list --output table
```

### Common causes

- Wrong service connection.
- Service principal lacks role.
- Secret expired.
- Variable group not authorized.
- Agent cannot reach private resource.
- Different Terraform/provider version.
- Missing backend credentials.
- Environment approval not granted.

### Resolution

- Fix service connection.
- Assign least-privilege role.
- Rotate expired secret or use workload identity federation.
- Authorize variable group.
- Use self-hosted agent for private network.
- Pin tool versions.

### Takeaway summary

Pipeline failures are often identity, context, variables, or network differences from your local machine.

---

## 24. Bicep or ARM deployment failure

### Interview freeze point

The template is valid JSON or Bicep, but deployment fails.

### Strong interview answer

> “I would check whether the failure is compile-time, validation-time, or deployment-time. Then I would inspect the deployment operation details to find the exact resource and error. Many ARM/Bicep failures are dependencies, names, locations, API versions, quotas, policy, or permissions.”

### Symptoms

- Template validation fails.
- Deployment partially succeeds.
- Resource name invalid.
- Dependency not ready.
- Policy denies deployment.
- Quota exceeded.
- API version issue.

### Diagnostic commands

Bicep build:

```bash
az bicep build --file main.bicep
```

Validate:

```bash
az deployment group validate \
  --resource-group "<rg>" \
  --template-file main.bicep \
  --parameters main.parameters.json
```

Deploy:

```bash
az deployment group create \
  --resource-group "<rg>" \
  --template-file main.bicep \
  --parameters main.parameters.json
```

Show operations:

```bash
az deployment operation group list \
  --resource-group "<rg>" \
  --name "<deployment-name>" \
  --output table
```

### Common causes

- Missing dependency.
- Wrong resource name format.
- Wrong location.
- Unsupported SKU.
- Policy denial.
- Role missing.
- Resource provider not registered.
- Quota limit.
- API version mismatch.

### Example dependency

```bicep
resource plan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'P1v3'
  }
}

resource app 'Microsoft.Web/sites@2022-09-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: plan.id
  }
}
```

The reference to `plan.id` creates an implicit dependency.

### Takeaway summary

For ARM/Bicep, inspect deployment operations. The top-level error often hides the real failing resource.

---

## 25. Terraform on Azure state or provider issue

### Interview freeze point

Terraform fails against Azure, and the issue could be state, provider, identity, or policy.

### Strong interview answer

> “I would check the AzureRM provider configuration, subscription and tenant IDs, backend state access, provider version, service principal or managed identity permissions, Azure Policy, and the actual plan. Terraform Azure issues often combine IaC state with Azure RBAC and policy.”

### Symptoms

- Terraform plan fails with authorization error.
- Apply fails with policy violation.
- State backend access denied.
- Resource already exists.
- Provider cannot register resource provider.
- Different plan locally and in CI.

### Example provider

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
```

### Remote backend example

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                  = "prod/app/terraform.tfstate"
  }
}
```

### Common causes

- Wrong subscription.
- Service principal lacks role.
- State storage firewall blocks pipeline.
- Backend key points to wrong environment.
- Resource exists but not imported.
- Azure Policy denies deployment.
- Provider version changed behavior.
- Resource provider not registered.

### Resolution examples

Register provider:

```bash
az provider register --namespace Microsoft.ContainerService
```

Import existing resource:

```bash
terraform import azurerm_resource_group.app /subscriptions/<sub-id>/resourceGroups/rg-app
```

### Takeaway summary

Terraform on Azure requires both Terraform state correctness and Azure platform permissions/policy correctness.

---

## 26. Azure Monitor logs missing

### Interview freeze point

The app is failing, but there are no logs.

### Strong interview answer

> “I would check whether diagnostic settings are enabled, whether logs are routed to the correct Log Analytics workspace, whether the resource supports the log category, and whether the query time range or table is correct.”

### Symptoms

- No logs in Log Analytics.
- Metrics exist but logs do not.
- Diagnostic setting missing.
- Logs go to wrong workspace.
- Query returns no results.
- App logging disabled.

### Diagnostic commands

List diagnostic settings:

```bash
az monitor diagnostic-settings list \
  --resource "<resource-id>"
```

List workspaces:

```bash
az monitor log-analytics workspace list --output table
```

### Common causes

- Diagnostic settings not enabled.
- Wrong workspace.
- Wrong log category.
- Ingestion delay.
- Query time range too narrow.
- App logs disabled.
- Network/firewall prevents agent from sending logs.
- Data collection rule misconfigured.

### Example diagnostic setting

```bash
az monitor diagnostic-settings create \
  --name send-to-law \
  --resource "<resource-id>" \
  --workspace "<workspace-resource-id>" \
  --logs '[{"category":"AuditEvent","enabled":true}]' \
  --metrics '[{"category":"AllMetrics","enabled":true}]'
```

### KQL example

```kusto
AzureActivity
| where TimeGenerated > ago(2h)
| where ResourceGroup == "rg-app"
| order by TimeGenerated desc
```

### Takeaway summary

No logs usually means diagnostic settings, workspace routing, category selection, or query scope is wrong.

---

## 27. Alert not firing

### Interview freeze point

Monitoring exists, but nobody gets notified.

### Strong interview answer

> “I would check the alert rule scope, condition, evaluation frequency, time window, metric namespace, action group, suppression settings, and whether the underlying metric or log query actually returns data.”

### Symptoms

- Incident happened but no alert.
- Alert rule enabled but quiet.
- Action group not notified.
- Query alert returns no rows.
- Metric alert threshold never crossed.
- Alert fired but notification failed.

### Diagnostic steps

- Check alert rule enabled.
- Check scope.
- Check condition.
- Check action group.
- Test action group.
- Query the data manually.
- Check alert processing rules.

### KQL example

```kusto
AppRequests
| where TimeGenerated > ago(5m)
| where Success == false
| summarize failures = count()
```

### Common causes

- Wrong resource scope.
- Wrong metric namespace.
- Query returns no results.
- Threshold too high.
- Evaluation period too long.
- Action group disabled or wrong email/webhook.
- Alert processing rule suppresses notification.
- Logs not ingested.

### Resolution

- Fix scope and condition.
- Test query.
- Lower threshold if appropriate.
- Fix action group.
- Disable accidental suppression.
- Add synthetic test alerts.

### Takeaway summary

An alert needs data, a correct condition, and a working notification path.

---

## 28. Cost spike or budget overrun

### Interview freeze point

Cloud cost questions test operational maturity.

### Strong interview answer

> “I would identify which subscription, resource group, service, meter, region, and tag changed. Then I would check recent deployments, scaling events, unattached resources, snapshots, logs ingestion, egress, premium SKUs, and idle compute. I would fix the driver and add budgets, alerts, and tagging.”

### Symptoms

- Monthly Azure bill spikes.
- Budget alert triggered.
- Log Analytics cost grows.
- NAT Gateway or bandwidth charges high.
- Unused disks or public IPs remain.
- AKS or VM scale set grew unexpectedly.

### Diagnostic commands

List resources by group:

```bash
az resource list \
  --resource-group "<rg>" \
  --output table
```

Find unattached managed disks:

```bash
az disk list \
  --query "[?managedBy==null].[name,resourceGroup,diskSizeGb,sku.name]" \
  --output table
```

Find public IPs:

```bash
az network public-ip list \
  --query "[].[name,resourceGroup,ipAddress,sku.name]" \
  --output table
```

### Common causes

- Oversized VMs.
- Idle VMs left running.
- Unattached disks.
- Old snapshots.
- Premium storage.
- Log Analytics ingestion.
- Data egress.
- NAT Gateway processing.
- AKS node pool scale-up.
- App Service Plan overprovisioned.
- Missing tags.

### Resolution

- Stop or resize idle compute.
- Delete unattached disks after validation.
- Reduce log volume.
- Add retention policies.
- Right-size SKUs.
- Use autoscaling carefully.
- Add budgets and alerts.
- Enforce tags with policy.

### Budget example

```bash
az consumption budget create \
  --budget-name prod-monthly-budget \
  --amount 5000 \
  --time-grain Monthly \
  --category Cost \
  --start-date 2026-05-01 \
  --end-date 2027-05-01
```

### Takeaway summary

Cost spikes are production incidents. Find the meter, resource, and change that caused the increase.

---

## 29. Resource provider not registered

### Interview freeze point

A deployment fails even though permissions seem correct.

### Strong interview answer

> “Azure services are exposed through resource providers. If the provider namespace is not registered in the subscription, deployments can fail. I would check the provider registration state and register it if approved.”

### Symptoms

- Deployment fails with provider not registered.
- New service cannot be created.
- Works in one subscription but not another.
- Terraform or Bicep fails on specific resource type.

### Diagnostic commands

List providers:

```bash
az provider list --output table
```

Show provider:

```bash
az provider show \
  --namespace Microsoft.ContainerService \
  --query "registrationState"
```

### Resolution

Register provider:

```bash
az provider register --namespace Microsoft.ContainerService
```

Check status:

```bash
az provider show \
  --namespace Microsoft.ContainerService \
  --query "registrationState"
```

### Common provider namespaces

```text
Microsoft.Compute
Microsoft.Network
Microsoft.Storage
Microsoft.ContainerService
Microsoft.Web
Microsoft.KeyVault
Microsoft.Sql
Microsoft.Insights
```

### Interview caution

In governed environments, provider registration may require approval because it enables use of new resource types.

### Takeaway summary

Provider registration is a subscription-level prerequisite for many Azure services.

---

## 30. Quota or regional capacity issue

### Interview freeze point

Deployment fails even though the template and permissions are correct.

### Strong interview answer

> “I would check subscription quotas, regional limits, SKU availability, and capacity errors. Azure capacity and quota issues often appear during VM, AKS, GPU, public IP, or networking deployments.”

### Symptoms

- VM creation fails.
- AKS scale-up fails.
- Quota exceeded error.
- SKU not available in region.
- Regional capacity error.
- Public IP or vCPU limit reached.

### Diagnostic commands

Check compute usage:

```bash
az vm list-usage \
  --location westeurope \
  --output table
```

Check SKU availability:

```bash
az vm list-skus \
  --location westeurope \
  --size Standard_D \
  --output table
```

### Common causes

- vCPU quota reached.
- Specific VM family quota reached.
- Region lacks capacity for SKU.
- Public IP quota reached.
- Managed disk limit.
- AKS node pool needs more quota.
- GPU quota not approved.

### Resolution

- Request quota increase.
- Use different VM size.
- Use different region or zone.
- Reduce unused capacity.
- Split workloads.
- Plan capacity before scale events.

Request quota increase through Azure portal or quota APIs depending on quota type.

### Example mitigation

If `Standard_D4s_v5` is unavailable, test another compatible SKU:

```bash
az vm list-skus \
  --location westeurope \
  --zone \
  --output table
```

### Takeaway summary

Not every deployment failure is code. Azure quota and regional capacity are real operational limits.

---

# Bonus: Azure interview answer frameworks

## Framework 1: The Azure outage answer

Use this when asked:

> “An Azure-hosted application is down. What do you do?”

```text
1. Confirm user-facing symptom.
2. Check scope: one app, one region, one subnet, one subscription, or global.
3. Check Azure Service Health and Resource Health.
4. Check recent deployments and Activity Log.
5. Check app logs and metrics.
6. Check identity and Key Vault dependencies.
7. Check network path, DNS, NSGs, UDRs, private endpoints.
8. Check compute/platform health.
9. Apply safest fix or rollback.
10. Verify with synthetic and user-level checks.
```

Interview version:

> “I would separate platform health, recent change, application failure, dependency failure, identity, and network path. Azure gives evidence through Activity Log, Resource Health, metrics, logs, and Network Watcher.”

---

## Framework 2: The Azure networking answer

Use this when asked:

> “A resource cannot connect to another resource. How do you troubleshoot?”

```text
1. Identify source and destination.
2. Test DNS resolution.
3. Check effective routes.
4. Check NSGs.
5. Check firewalls.
6. Check private endpoint DNS.
7. Check service-level firewall.
8. Check identity if service requires auth.
9. Use Network Watcher.
10. Verify from the actual source subnet.
```

Interview version:

> “I follow the packet: source identity, DNS, route, NSG, firewall, private endpoint, destination listener, and service auth.”

---

## Framework 3: The Azure identity answer

Use this when asked:

> “Something gets Access Denied in Azure. What do you check?”

```text
1. Identify the principal.
2. Identify the exact action.
3. Check tenant and subscription.
4. Check role assignment.
5. Check scope.
6. Check deny assignments.
7. Check Azure Policy.
8. Check PIM activation.
9. Check data-plane versus management-plane permission.
10. Retest the exact action.
```

Interview version:

> “Azure permissions are principal, role, scope, and sometimes data-plane specific. Contributor does not always mean data access.”

---

## Framework 4: The deployment failure answer

Use this when asked:

> “An Azure deployment failed. What do you do?”

```text
1. Read exact error.
2. Check deployment operations.
3. Identify failed resource.
4. Check permissions.
5. Check policy.
6. Check quota and SKU availability.
7. Check provider registration.
8. Check dependencies.
9. Fix template or platform prerequisite.
10. Redeploy safely.
```

Interview version:

> “I do not stop at the top-level deployment error. I inspect deployment operations to find the exact resource and reason.”

---

## Framework 5: The production safety answer

Use this when asked:

> “How do you make Azure changes safely?”

```text
1. Use IaC.
2. Review plan/diff.
3. Use least privilege.
4. Deploy to lower environment first.
5. Use approvals for prod.
6. Use staged rollout or slots.
7. Monitor metrics and logs.
8. Keep rollback path.
9. Tag and document resources.
10. Add policy and alerts to prevent recurrence.
```

Interview version:

> “Safe Azure changes require controlled identity, repeatable IaC, clear environment separation, observability, and rollback.”

---

# Common Azure interview traps and better answers

## Trap 1: “Can we just give the user Owner?”

Weak answer:

> “Yes, that will fix it.”

Better answer:

> “It might fix the symptom but violates least privilege. I would identify the exact action and assign the narrowest role at the correct scope.”

---

## Trap 2: “The VM is running, so the app should be reachable, right?”

Weak answer:

> “Yes.”

Better answer:

> “Not necessarily. I would check NSGs, routes, guest firewall, listener port, public/private path, and app health.”

---

## Trap 3: “Private Endpoint exists, so private access works?”

Weak answer:

> “Yes.”

Better answer:

> “Not automatically. DNS must resolve the service FQDN to the private endpoint IP from the client network.”

---

## Trap 4: “Contributor means storage data access?”

Weak answer:

> “Yes.”

Better answer:

> “Not always. Azure separates management-plane and data-plane access. Blob data access usually needs Storage Blob Data roles.”

---

## Trap 5: “Deployment failed, so the template is wrong?”

Weak answer:

> “Probably.”

Better answer:

> “Maybe, but it could also be policy, quota, provider registration, permissions, naming, region, SKU, or dependency order.”

---

## Trap 6: “Logs are missing, so nothing happened?”

Weak answer:

> “Yes.”

Better answer:

> “No. Diagnostic settings may not be enabled or may route to the wrong workspace. I would check Activity Log, metrics, diagnostic settings, and workspace queries.”

---

## Trap 7: “The pipeline failed, so Azure is broken?”

Weak answer:

> “Maybe.”

Better answer:

> “I would compare local and pipeline context: service connection, subscription, variables, secrets, agent network, and tool versions.”

---

# Azure interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| RBAC failure | Access denied | Principal, role, scope | Assign least privilege role |
| Policy denial | Deployment blocked | Policy assignment/error | Fix tags/SKU/public access/etc. |
| Wrong context | Resource not found/wrong deploy | Tenant/subscription | Set explicit context |
| VM SSH/RDP fail | Cannot connect | NSG/effective rules/path | Fix NSG, route, firewall, Bastion |
| NSG issue | Traffic blocked | Effective NSG rules | Fix priority/source/port |
| UDR issue | Traffic misrouted | Effective routes/next hop | Fix route/NVA/firewall |
| VNet peering fail | VNets cannot talk | Both peerings/routes/NSGs | Fix peering/NSG/UDR |
| Private endpoint fail | Resolves public IP | DNS zone/VNet link | Fix private DNS |
| DNS failure | Name not resolving | Resolver path | Fix VNet DNS/forwarders |
| Load Balancer unhealthy | Backend not used | Health probe | Fix probe/app/NSG |
| App Gateway 502 | Backend unhealthy | Backend health | Fix probe/TLS/host/NSG |
| Storage access denied | Blob/file access fails | Data-plane role/firewall | Assign role/fix network |
| Storage private issue | Network denied | Firewall/private DNS | Fix subnet/private endpoint |
| Key Vault denied | Secret access fails | RBAC/access policy/network | Fix identity and network |
| Managed identity fail | Token/access issue | Identity and role | Enable identity/assign role |
| App Service fail | 500/502/startup issue | App logs/settings | Fix runtime/config/port |
| App Service VNet issue | Cannot reach private resource | VNet integration/DNS | Fix integration/private DNS |
| Azure SQL fail | Connection timeout/auth fail | Firewall/DNS/auth | Fix firewall/private endpoint/auth |
| AKS network issue | Pod connectivity fail | DNS/policy/UDR/CNI | Fix DNS/policy/routes |
| AKS scheduling fail | Pods Pending | Events/node pool/quota | Fix requests/scale/quota |
| AKS upgrade fail | Upgrade stuck | PDB/deprecated APIs | Fix workloads/capacity |
| ACR pull fail | ImagePullBackOff | AcrPull/image/tag | Attach ACR/fix permissions |
| Pipeline fail | Local works, CI fails | Service connection/context | Fix identity/vars/agent |
| Bicep/ARM fail | Deployment error | Deployment operations | Fix failed resource cause |
| Terraform Azure fail | Plan/apply/state issue | Provider/backend/RBAC | Fix state/provider/identity |
| Logs missing | No logs in workspace | Diagnostic settings | Enable correct logs |
| Alert not firing | No notification | Scope/query/action group | Fix rule/action group |
| Cost spike | Budget exceeded | Cost by resource/meter | Right-size/clean/tag |
| Provider not registered | Resource type fails | Provider state | Register provider |
| Quota/capacity issue | Deployment scale fails | Usage/SKU availability | Request quota/change SKU |

---

# Strong closing takeaway

Azure interviews are not just service-name quizzes. They are operational judgment tests.

A weak answer sounds like:

> “I would check Azure.”

A strong answer sounds like:

> “I would check the exact resource, identity, network path, policy, deployment history, logs, metrics, and platform health. Then I would make the smallest safe change and verify from the user’s path.”

Azure issues usually leave evidence somewhere: Activity Log, deployment operations, metrics, diagnostic logs, Resource Health, effective routes, effective NSG rules, policy compliance, or identity assignments.

When you freeze, return to this sequence:

```text
Context → Identity → Network → DNS → Service config → Logs → Metrics → Policy → Recent change → Fix → Verify
```

That sequence will carry you through most Azure interview questions.

---

# Final takeaway summaries

## The one-minute summary

Azure issues usually come from identity, RBAC, wrong subscription context, Azure Policy, networking, DNS, private endpoints, NSGs, route tables, storage firewalls, Key Vault access, App Service configuration, Azure SQL firewalls, AKS scheduling, ACR pulls, deployment failures, monitoring gaps, cost spikes, provider registration, or quota limits. The best answer starts by identifying the failing path and checking Azure evidence.

## The senior-engineer summary

A senior Azure engineer understands that cloud failures are often cross-layer. A storage issue may be RBAC, firewall, private DNS, or SAS expiry. A VM issue may be NSG, UDR, guest firewall, or service health. A deployment issue may be policy, quota, provider registration, or identity. Seniority is shown by isolating the layer, proving the cause, and making the smallest safe fix.

## The interview survival summary

When your mind goes blank, say:

> “I would first confirm the subscription, tenant, resource, and exact failure. Then I would check identity and RBAC, Azure Policy, network path, DNS, service firewall, private endpoint configuration, logs, metrics, and recent deployments. I would prove the cause, apply the smallest safe fix, and verify from the same path the user or workload uses.”

That answer works across most Azure interview scenarios.
