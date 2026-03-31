# Advanced Azure Infrastructure with Terraform

## Overview

You'll create a scalable web application infrastructure in Azure using Terraform. The infrastructure will include a Virtual Machine Scale Set (VMSS) behind a load balancer with proper security and scaling configurations.

> **Tech Stack:** Terraform `>= 1.9.0` · AzureRM Provider `~> 4.14.0` · Ubuntu 22.04 LTS · Azure Load Balancer (Standard SKU)

---

## Project Structure

```
.
├── provider.tf          # Azure provider & Terraform version constraints
├── backend.tf           # Remote state configuration (Azure Blob Storage)
├── variables.tf         # Input variable declarations with validations
├── terraform.tfvars     # Actual variable values (env, region, sizing)
├── locals.tf            # Common tags, naming convention, NSG rules
├── vnet.tf              # VNet, Subnets, NSG, Load Balancer, NAT Gateway
├── vmss.tf              # Virtual Machine Scale Set (Ubuntu 22.04)
├── autoscale.tf         # CPU-based autoscale rules
├── user-data.sh         # Cloud-init script (Apache + PHP setup)
└── images/              # Screenshots and diagrams for this readme
```

---

## Architecture

```
Internet
    ↓
[Azure Load Balancer] ← Public IP (Standard SKU, Static)
    ↓  Port 80 (HTTP)
[NSG] ← Inbound rules: allow LB, deny all others
    ↓
[VMSS Instances] ← Ubuntu 22.04, NO Public IP
    ↓
[NAT Gateway] ← Outbound internet access for instances
```

![Architecture Diagram](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/diagram-export-3-30-2026-6_58_35-PM.png)

---

## Requirements

### Base Infrastructure

1. Create a resource group in one of these regions:
   - East US
   - West Europe
   - Southeast Asia
   - Central India

> **Validation Rule:** The `region` variable in `variables.tf` includes a validation block that restricts deployments to only the four allowed regions. Any other value will throw an error during `terraform plan`.

```hcl
validation {
  condition = contains(
    ["eastus", "westeurope", "southeastasia", "centralindia"],
    var.region
  )
  error_message = "region must be one of: eastus, westeurope, southeastasia, centralindia."
}
```

---

### Networking

1. Create a VNet with two subnets:
   - **Application subnet** — VMSS instances live here (`10.0.0.0/20`)
   - **Management subnet** — Reserved for future jumpbox use (`10.0.16.0/24`)

2. Configure an NSG that:
   - Only allows traffic from the load balancer to VMSS
   - Uses **dynamic blocks** for rule configuration
   - Denies all other inbound traffic

#### Traffic Flow

```
Internet
    ↓
[Azure Load Balancer] ← has Public IP
    ↓
[NSG] ← port-level rules
    ↓
[VMSS Instances] ← NO Public IP
```

#### NSG Rules Summary

| Priority | Name | Port | Source | Access |
|---|---|---|---|---|
| 100 | allow-http-from-lb | 80 | * | Allow |
| 101 | allow-https-from-lb | 443 | * | Allow |
| 102 | allow-ssh-from-lb | 22 | AzureLoadBalancer | Allow |
| 103 | allow-health-probe | 80 | AzureLoadBalancer | Allow |
| 4096 | deny-all-inbound | * | * | Deny |

> **Why dynamic blocks?** NSG rules are defined as a list of objects in `locals.tf` and rendered using a `dynamic "security_rule"` block in `vnet.tf`. This avoids repetitive HCL and makes adding/removing rules as simple as editing the locals list.

![NSG Dynamic Block](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330183908.png)

---

### Compute

#### Finding Available VM SKUs

Before choosing a VM size, verify it is available in your target region using:

```bash
az vm list-skus \
  --location centralindia \
  --resource-type virtualMachines \
  --query "[?restrictions[0].reasonCode!='NotAvailableForSubscription' && contains(name, 'Standard_B')].[name]" \
  --output table
```

![Available SKUs Query](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330184237.png)

![SKU Results](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330184251.png)

#### VMSS Configuration

1. Set up a VMSS with:
   - Ubuntu 22.04 LTS (Jammy)
   - VM sizes selected via `lookup` function based on environment:

     | Environment | VM Size |
     |---|---|
     | Dev | Standard_D2s_v4 |
     | Stage | Standard_D2s_v4 |
     | Prod | Standard_D2s_v4 |

> **Why `lookup`?** Even though all environments use the same size here, using `lookup(var.environment, {...})` makes it trivial to upgrade Prod to a larger SKU (e.g. `Standard_D4s_v4`) in the future without restructuring the code.

```hcl
sku_name = lookup({
  dev   = "Standard_D2s_v4"
  stage = "Standard_D2s_v4"
  prod  = "Standard_D2s_v4"
}, var.environment, "Standard_D2s_v4")
```

#### Autoscaling

2. Configure auto-scaling:
   - Scale **in** when CPU < 10% (for 2 minutes)
   - Scale **out** when CPU > 75% (for 5 minutes)
   - Minimum instances: **2**
   - Maximum instances: **3**

> **Cooldown period:** Both scale-in and scale-out actions have a 5-minute cooldown (`PT5M`) to prevent rapid instance flapping.

![Autoscale Configuration](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330183001.png)

![Autoscale Rules](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330182514.png)

---

### Load Balancer

1. Create an Azure Load Balancer:
   - **Public IP** — Standard SKU, Static, Zone-redundant (`1,2,3`)
   - **Backend pool** connected to VMSS via `load_balancer_backend_address_pool_ids`
   - **Health probe** on port 80 (`HTTP /`)
   - **LB Rule** — Frontend port 80 → Backend port 80
   - **NAT Rule** — SSH access via ports `50000–50119` → port `22`

> **Why Standard SKU?** Standard Load Balancer is required for zone redundancy and works with Standard Public IPs. Basic SKU does not support availability zones.

![Load Balancer Setup](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330183126.png)

---

## Technical Requirements

### Variables

All input variables are declared in `variables.tf` with descriptions and validation rules. Actual values are set in `terraform.tfvars`.

📄 [`variables.tf`](https://github.com/JiNaL1112/Terraform-Azure-Project1/blob/main/variables.tf)

| Variable | Description | Default |
|---|---|---|
| `environment` | dev / stage / prod | — |
| `region` | Azure region (restricted) | — |
| `prefix` | Resource name prefix | — |
| `min_instances` | Min VMSS instances | 2 |
| `max_instances` | Max VMSS instances | 3 |
| `default_instances` | Initial instance count | 2 |
| `vnet_address_space` | VNet CIDR | `10.0.0.0/16` |
| `app_subnet_prefix` | App subnet CIDR | `10.0.0.0/20` |
| `mgmt_subnet_prefix` | Mgmt subnet CIDR | `10.0.16.0/24` |

---

### Locals

All shared values are centralised in `locals.tf` to avoid repetition across resource files.

📄 [`locals.tf`](https://github.com/JiNaL1112/Terraform-Azure-Project1/blob/main/locals.tf)

| Local | Purpose |
|---|---|
| `common_tags` | Applied to every resource for cost tracking & governance |
| `name_prefix` | `"${var.prefix}-${var.environment}"` — consistent resource naming |
| `network_config` | Centralised CIDR references used in `vnet.tf` |
| `nsg_rules` | List of rule objects consumed by the dynamic block |

---

### Dynamic Blocks

Dynamic blocks are used in two places to avoid repetitive HCL:

1. **NSG rules** — `vnet.tf` iterates over `local.nsg_rules` list
2. **Load balancer rules** — frontend/backend port mappings

> **Benefit:** Adding a new NSG rule only requires adding one object to the list in `locals.tf` — no changes needed in `vnet.tf`.

![Dynamic Blocks](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330183908.png)

---

### Remote State

State is stored remotely in Azure Blob Storage to enable team collaboration and prevent state conflicts.

```hcl
backend "azurerm" {
  resource_group_name  = "tfstate-day04"
  storage_account_name = "day0414730"
  container_name       = "tfstate"
  key                  = "dev.terraform.tfstate"
}
```

> **Why remote state?** Local state files are risky — they can be lost, corrupted, or cause conflicts when multiple team members run Terraform simultaneously. Azure Blob Storage provides locking via lease mechanism.

---

## Deployment

### Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.9.0`
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) logged in (`az login`)
- SSH key pair in `.ssh/key` and `.ssh/key.pub`

### Steps

```bash
# 1. Initialise — downloads providers and connects to remote state
terraform init

# 2. Preview changes
terraform plan

# 3. Apply infrastructure
terraform apply

# 4. Destroy when done
terraform destroy
```

---

## Final View

![Azure Portal - Resource Group](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330183833.png)

---

## Project Structure on Azure Portal

![Azure Portal Overview](https://raw.githubusercontent.com/JiNaL1112/Terraform-Azure-Project1/main/images/Pasted%20image%2020260330184710.png)
