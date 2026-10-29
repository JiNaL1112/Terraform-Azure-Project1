# Accessing the VMSS Instances

The VMSS instances have **no public IP**. Access is possible in two ways:

| Method | Interactive shell | Needs NSG change | Used for |
|---|---|---|---|
| Azure Run Command | No | No | Quick checks and one-off commands |
| SSH via Load Balancer NAT rule | Yes | Yes (your IP only) | Full shell access |

> **Environment:** Resource group `myapp-dev-rg`, region `centralindia`, Flexible orchestration scale set (`azurerm_orchestrated_virtual_machine_scale_set`), admin user `azureuser`.

---

## Method 1: Run Command (no SSH)

Works through the Azure control plane, so the NSG is not involved.

```powershell
az login

# list instance names
az vm list -g myapp-dev-rg -o table

# run a command on an instance
az vm run-command invoke -g myapp-dev-rg -n <vm-name> --command-id RunShellScript --scripts "hostname; systemctl status apache2 --no-pager"
```

Tips:

- Add `--query "value[0].message" -o tsv` to print output with real line breaks.
- On Flexible scale sets use `az vm run-command`, not `az vmss run-command`.
- **PowerShell note:** `\` is not a line continuation. Put the command on one line, or end each line with a backtick (`` ` ``).

### Verified checks

- Apache is `active (running)` and enabled at boot.
- `curl http://localhost` returns `200`.
- `/var/www/html` contains `index.html` and `index.php`.
- Cloud-init finished without errors (`user-data.sh` ran fully).

---

## Method 2: SSH through the Load Balancer NAT rule

### How it works

```
Your PC --(IPv4)--> LB public IP : 50000-50119
        --> NSG (allow-ssh-from-my-ip) --> VMSS instance : 22
```

- `azurerm_lb_nat_rule "ssh"` in `vnet.tf` maps frontend ports `50000-50119` to port `22` on instances in the backend pool.
- The NSG allows port 22 **only from your public IPv4 `/32`**. The `deny-all-inbound` rule blocks everything else.
- The `AzureLoadBalancer` tag only covers probe traffic, so it does not allow your SSH connection by itself.

### Step 1: Get your public IPv4

```powershell
curl.exe -4 ifconfig.me
```

> **Gotcha:** plain `curl.exe ifconfig.me` may return an IPv6 address. The load balancer and NSG rule use IPv4, so always use `-4`. The `-4` fallback is `curl.exe -4 https://api.ipify.org`.

### Step 2: Add the variable

`variables.tf`:

```hcl
variable "my_ip" {
  description = "Public IP (CIDR) allowed to SSH, e.g. 203.0.113.25/32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.my_ip)) && var.my_ip != "0.0.0.0/0"
    error_message = "my_ip must be a valid IPv4 CIDR and must not be 0.0.0.0/0."
  }
}
```

`terraform.tfvars`:

```hcl
my_ip = "<your.ipv4>/32"
```

### Step 3: Add the NSG rule

In `locals.tf`, add to `nsg_rules` before `deny-all-inbound`:

```hcl
{
  name                       = "allow-ssh-from-my-ip"
  priority                   = 104
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = var.my_ip
  destination_address_prefix = "VirtualNetwork"
},
```

```powershell
terraform apply
```

### Step 4: Fix private key permissions (Windows, once)

OpenSSH on Windows rejects keys readable by other users.

```powershell
icacls .ssh\key /inheritance:r
icacls .ssh\key /grant:r "$($env:USERNAME):(R)"
```

### Step 5: Get the LB address

```powershell
az network public-ip show -g myapp-dev-rg -n myapp-dev-lb-pip --query "{ip:ipAddress, fqdn:dnsSettings.fqdn}" -o table
```

Current values:

- IP: `4.187.159.82`
- FQDN: `myapp-dev-rg-needed-wren.centralindia.cloudapp.azure.com`

### Step 6: Connect

```powershell
ssh -i .ssh\key -p 50000 azureuser@4.187.159.82
```

- The first connection shows a host fingerprint prompt. Type `yes`.
- Use port `50001` for the second instance.
- A successful login shows an Ubuntu 22.04 banner and a prompt like `azureuser@vmss-terraformXXXXXX:~$`.

### Optional: verify the host fingerprint

```powershell
az vm run-command invoke -g myapp-dev-rg -n <vm-name> --command-id RunShellScript --scripts "ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub" --query "value[0].message" -o tsv
```

Port 50000 maps to one specific instance, so make sure `<vm-name>` is the instance behind that port.

### Useful commands once connected

```bash
hostname
sudo systemctl status apache2 --no-pager
ls -la /var/www/html
sudo tail -n 50 /var/log/apache2/access.log
```

---

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Timeout | Your public IP changed. Re-run `curl.exe -4 ifconfig.me`, update `my_ip`, run `terraform apply`. |
| `Connection refused` | Port not mapped to an instance. Try `50001`, or inspect the rule: `az network lb inbound-nat-rule show -g myapp-dev-rg --lb-name myapp-dev-lb -n ssh` |
| `Permission denied (publickey)` | Use `.ssh\key` (matches `.ssh/key.pub` in `vmss.tf`) with user `azureuser`. |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | An instance was replaced. Run `ssh-keygen -R "[4.187.159.82]:50000"` and retry. |
| `Unexpected token` errors in PowerShell | You used `\` line continuation. Use one line or backticks. |
| Fingerprint differs from expected | Port maps to a different instance than the one you checked. |

---

## Security notes

- **Never use `*` or `0.0.0.0/0` as the SSH source.** The `my_ip` validation blocks this.
- **Close SSH when finished.** Remove the `allow-ssh-from-my-ip` rule (or set `my_ip` to a placeholder such as `192.0.2.1/32`) and run `terraform apply`.
- **Keep keys private.** `.ssh/` is in `.gitignore`. If a private key is ever shared or pasted anywhere, treat it as compromised: generate a new pair with `ssh-keygen -t ed25519 -f .ssh\key`, update `vmss.tf` to read the new `.pub`, apply, and replace the instances so they pick it up.
- **Password login is disabled** (`disable_password_authentication = true`).
- **Commit `.terraform.lock.hcl`** for reproducible provider versions (remove it from `.gitignore`).

## More secure alternative: Azure Bastion

For production-style setups, remove `azurerm_lb_nat_rule "ssh"`, add an `AzureBastionSubnet` (`/26`) and an `azurerm_bastion_host` (Standard SKU, `tunneling_enabled = true`), and allow SSH in the NSG only from the Bastion subnet. Connect with:

```powershell
az network bastion ssh --name myapp-dev-bastion -g myapp-dev-rg --target-resource-id <vm-id> --auth-type ssh-key --username azureuser --ssh-key .ssh\key
```

Bastion Standard costs roughly $140/month while it exists, so destroy it when not in use.