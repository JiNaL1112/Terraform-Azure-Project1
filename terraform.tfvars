# ============================================================
# terraform.tfvars
# Actual values for the variables declared in variables.tf.
# Change environment / region here to target a different env.
# ============================================================

environment = "dev"
region      = "centralindia"
prefix      = "myapp"

# # Scaling limits (assignment: min=2, max=5)
# min_instances     = 2
# max_instances     = 5
# default_instances = 2

# # Network CIDRs
# vnet_address_space = "10.0.0.0/16"
# app_subnet_prefix  = "10.0.0.0/20"
# mgmt_subnet_prefix = "10.0.16.0/24"
