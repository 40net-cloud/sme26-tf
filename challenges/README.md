# Ideas for trigering challenge errors (very messy notes)

## lacework/dspm/azure incompatible with azurerm 5.0.0

*New azurerm provider version (5.0.0) removes some defaults that we were leveraging in lacework dspm azure module. It's a real-life problem example. The only problem is we need a real azure and lacework subs for it to work.*

```
module "lacework_azure_dspm" {
  source                    = "lacework/dspm/azure"
  lacework_integration_name = "azure-dspm-demo"
  regions                   = ["Italy North"]
  scanning_subscription_id  = var.scanning_sub_id
  scan_frequency_hours = 24

  # Uncomment to control which datastores to scan (filter_mode: INCLUDE, EXCLUDE, or ALL)
  datastore_filters = {
    filter_mode     = "INCLUDE"
    datastore_names = ["blahblahblah"]
  }
}
```

#### Fix

```
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "< 5.0.0"
    }
  }
}
```

## Resource index needs to be known before plan

*A classic of for_each looping. The code below demonstrates the problem but is completely artificial. We need something more "real-life" imho*

```
locals {
  vpc_count = 2
}

resource "random_pet" "vpc_name" {
  count  = local.vpc_count
  length = 2
}

resource "aws_vpc" "test" {
  for_each = toset(random_pet.vpc_name[*].id)

  cidr_block = "10.0.1.0/24"
  tags = {
    Name = each.value
  }
}
```

### Plan error

Error: Invalid for_each argument
│ 
│   on 2.tf line 11, in resource "aws_vpc" "test":
│   11:   for_each = toset(random_pet.vpc_name[*].id)
│     ├────────────────
│     │ random_pet.vpc_name is tuple with 2 elements
│ 
│ The "for_each" set includes values derived from resource attributes that cannot be determined until apply, and so Terraform cannot determine the full set of keys that will identify the instances of this resource.
│ 
│ When working with unknown values in for_each, it's better to use a map value where the keys are defined statically in your configuration and where only the values contain apply-time results.
│ 
│ Alternatively, you could use the -target planning option to first apply only the resources that the for_each value depends on, and then apply a second time to fully converge.


## Sensitive value derivatives

This is a real problem from our module.
https://github.com/fortinetdev/terraform-google-cloud-modules/issues/2

The code in (./sensitive)[./sensitive] is - again - a bit artificial but is a good base to incorporate it in challenge lab. See the GitHub issue description for another example.

## Race and missing dependencies

get 2 dependent resources where prerequisite takes longer to deploy than dependant. Break dependency by hard-coding predictable value. Undeterministic apply phase error.

## Logged out (AWS or Azure)

The point is to trigger the "Invalid provider configuration" error which should be fixed without touching provider configuration. Works for logged out AWS/Azure CLI auth, but I have no good idea how to trigger it without creating an obvious hint.