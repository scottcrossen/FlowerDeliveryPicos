ruleset root {
  meta {
    logging on
    shares __testing
  }

  global {
    __testing = {
    }
  }

  rule children_add {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": "Flower Store Collection",
          "color": "#87cefa"
        } if not exists;
      raise wrangler event "child_creation"
        attributes {
          "name": "Driver Collection",
          "color": "#87cefa"
        } if not exists;
    }
  }

  rule children_driver_rules {
    select when wrangler child_initialized where event:attr("rs_attrs"){"name"} == "Driver Collection"
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
    select when wrangler child_initialized where event:attr("rs_attrs"){"name"} == "Flower Store Collection"
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
