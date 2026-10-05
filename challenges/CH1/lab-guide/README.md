# Challenge 1 — FortiGate in Azure

## What it deploys

```
Internet ──HTTPS :443 / SSH :22──► Public IP (<prefix>-pip)
                                        │
VNet 10.0.0.0/16                        ▼
 external 10.0.1.0/24 ── NIC-ext ─┐
                                  ├── FortiGate VM (<prefix>-fgt) ── data disk 30 GB (LUN 0)
 internal 10.0.2.0/24 ── NIC-int ─┘
                     NSG (<prefix>-nsg) on both NICs
```

```
.
├── main.tf          # provider, RG, VNet, subnets, NSG, PIP, NICs, VM, data disk
├── variables.tf     # inputs

```

## Before you start

```bash
az login
az account set --subscription "<your-subscription>"
```

## Make it deploy and fix bugs

```bash
terraform init
terraform plan -var "subscription_id=$(az account show --query id -o tsv)"
terraform apply -var "subscription_id=$(az account show --query id -o tsv)"
```

Questions:

1. Why does one bug appear only at `apply`, even though `plan` was clean?
2. After the failed `apply`, run `terraform state list`. What already exists in Azure? Will the next `apply` recreate it?
3. Your fix for the `apply` bug removes a hand-built string. How does that change Terraform's dependency graph? Check with `terraform graph`.

**Done when** the FortiGate login page opens at `https://<public-ip>`:

```bash
az network public-ip show -g <prefix>-rg -n <prefix>-pip --query ipAddress -o tsv
```

## Cleanup

```bash
terraform destroy
```

