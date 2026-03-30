# create autoscale resource that will decrease the number of instances if the azurerm_orchestrated_scale set cpu usaae is below 10% for 2 minutes
resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  target_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.vmss_terraform_tutorial.id
  enabled             = true
  profile {
    name = "autoscale"
    capacity {
      default = 2
      minimum = 2
      maximum = 3
    }

    # Scale OUT: CPU > 75% for 5 minutes → add 1 instance
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss_terraform_tutorial.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # Scale IN: CPU < 10% for 2 minutes → remove 1 instance
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss_terraform_tutorial.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT2M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }


    
  }
}