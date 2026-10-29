# ============================================================
# terraform.tfvars
# Actual values for the variables declared in variables.tf.
# Change environment / region here to target a different env.
# ============================================================

environment = "dev"
region      = "centralindia"
prefix      = "myapp"

# # Scaling limits (assignment: min=2, max=5)
min_instances     = 2
max_instances     = 3
default_instances = 2

# # Network CIDRs
vnet_address_space = "10.0.0.0/16"
app_subnet_prefix  = "10.0.0.0/20"
mgmt_subnet_prefix = "10.0.16.0/24"


azure_client_id = "6fc9e92b-db64-4922-a4ab-49b2919d39da"
azure_subscription_id = "2f4fdc5d-b5fe-43f5-b493-4000d77bc096"
azure_tenant_id = "b4d9976d-c095-4323-9940-00d8e8f6df90"

my_ip = "173.33.81.227"