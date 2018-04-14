ruleset root {
  meta {
    logging on
    shares __testing
    use module io.picolabs.wrangler alias wrangler
  }

  global {
    __testing = {
    }
    storeCollectionName = "Flower Store Collection"
    driverCollectionName = "Driver Collection"
  }

  rule children_add {
    select when wrangler ruleset_added where rids >< meta:rid
    pre {
      children = wrangler:children()
      storesExist = (children.filter(function(child) {
        child{"name"} == storeCollectionName
      }).length() != 0)
      driversExist = (children.filter(function(child) {
        child{"name"} == driverCollectionName
      }).length() != 0)
    }
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": storeCollectionName,
          "color": "#87cefa"
        } if not storesExist;
      raise wrangler event "child_creation"
        attributes {
          "name": driverCollectionName,
          "color": "#87cefa"
        } if not driversExist;
    }
  }

  rule children_driver_rules {
    select when wrangler child_initialized where event:attr("rs_attrs"){"name"} == driverCollectionName
    pre {
      eci = event:attr("eci")
    }
    every {
      event:send({
        "eci": eci,
        "eid": "install-ruleset",
        "domain": "wrangler",
        "type": "install_rulesets_requested",
        "attrs": {
          "rids": [
            "manage_drivers"
          ]
        }
      })
    }
  }

  rule children_store_rules {
    select when wrangler child_initialized where event:attr("rs_attrs"){"name"} == storeCollectionName
    pre {
      eci = event:attr("eci")
    }
    every {
      event:send({
        "eci": eci,
        "eid": "install-ruleset",
        "domain": "wrangler",
        "type": "install_rulesets_requested",
        "attrs": {
          "rids": [
            "manage_stores"
          ]
        }
      })
    }
  }
}
