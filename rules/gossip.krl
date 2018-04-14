ruleset gossip {
  meta {
    use module io.picolabs.subscription alias Subscriptions
    use module temperature_store
    logging on
    shares __testing, getRumors, getPeers, getPeer, makeSeen, getAllSubscriptions
    provides getRumors, getPeers, getPeer, makeSeen, getAllSubscriptions
  }

  global {
    __testing = {
      "queries": [ {
        "name": "getAllSubscriptions"
      }, {
        "name": "getPeers"
      }, {
        "name": "getPeer"
      }, {
        "name": "getRumors"
      }, {
        "name": "makeSeen"
      } ],
      "events": [  {
        "domain": "gossip",
        "type": "toggle_execution"
      }, {
        "domain": "gossip",
        "type": "set_heartbeat",
        "attrs": ["interval"]
      }, {
        "domain": "gossip",
        "type": "create_rumor",
        "attrs": [ "SensorID", "Temperature" ]
      }, {
        "domain": "gossip",
        "type": "link_nodes",
        "attrs": [ "eci", "name" ]
      } ]
    }

    // Helper/testing method to see what unions this pico belongs to.
    getAllSubscriptions = function() {
      Subscriptions:established()
    }

    // Helper/testing method to see what the current rumors are
    getRumors = function() {
      ent:rumors.defaultsTo({})
    }

    // Helper/testing method to see current peer states from entities
    getPeers = function() {
      ent:peers.defaultsTo({})
    }

    // Selects a peer that needs to be rumored to.
    getPeer = function() {
      // Select all "node" subscriptions
      possible_peers = Subscriptions:established("Tx_role","node").filter(function(subscription) {
        // filter based on criteria given in lab
        ent:peers{engine:getPicoIDByECI(subscription{"Tx"})} == ent:peers{meta:picoId}
        // Really this needs to be replaced with a "firstOption" but not everything is Scala.
      });
      // Return first valid but handle the 0 length case differently
      (possible_peers.length() == 0) => Subscriptions:established("Tx_role","node")[0]{"Tx"} | possible_peers[0]{"Tx"}
    }

    makeSeen = function() {
      ent:rumors.map(function(value, key) {
        // compose rumor increments and keys.
        rumor_keys_original = value.keys().sort("numeric");
        // Really we need a 'findFirst' function.
        rumor_keys = rumor_keys_original.filter(function(n) {
          rumor_keys_original.index(n) == n.as("Number")
        });
        // Return last valid seen count unless length is null. (Watch for edge case)
        rumor_keys.length() > 0 => rumor_keys[rumor_keys.length() - 1].as("Number") | rumor_keys_original[rumor_keys_original.length() - 1].as("Number");
      });
    }

    makeRumor = function(seen) {
      next = seen.map(function(seen_sequence, seen_id) {
        // Find correct sequence number for each seen value.
        sequence = seen_sequence.as("Number");
        rumorKeys = ent:rumors{[seen_id]}.keys();
        nextSequence = (sequence + 1).as("String");
        // Return count of what needs to be rumored if possible
        (rumorKeys >< nextSequence) => (sequence + 1) | sequence
      });
      // Filter previous list to only rumor about what updates there are.
      validNext = next.filter(function(this_sequence, pico_id) {
        seen{pico_id} != this_sequence
      });
      // Select all rumors that need updates (from above) and send that.
      new_rumors = ent:rumors.filter(function(value, pico_id) {
        not (seen >< pico_id)
      }).values(); // Only send values.
      // Handle the null case appropriately.
      (new_rumors.length() > 0) => new_rumors[0]{0} | (
        validNext.values().length() > 0
      ) => ent:rumors{[validNext.keys()[0], validNext.values()[0]]} | {};
    }

    send = defaction(eci, message, type) {
      // Follow the code template in lab. 'defaction' is a action wrapper
      event:send({
        "eci": eci,
        "domain": "gossip",
        "type": type,
        "attrs": {
          "eci": meta:eci,
          "message": message
        }
      });
    }
  }

  rule start_gossip {
    // I learned this little trick to start the gossiping when the rules are added:
    select when wrangler ruleset_added where rids >< meta:rid
    // initialize entities
    fired {
      ent:currentSequence := 0; // init to zero.
      ent:interval := 10;
      ent:turnedOn := true; // start in on mode.
      ent:rumors := getRumors();
      ent:peers := getPeers();
      raise gossip event "heartbeat"
    }
  }

  rule link_nodes {
    // Helper rule to establish gossip links
    select when gossip link_nodes
    pre {
      eci = event:attr("eci")
      name = event:attr("name")
    }
    every {
      event:send({
        "eci": eci,
        "domain": "wrangler",
        "type": "subscription",
        "attrs": {
          "name": name,
          "Rx_role": "node",
          "Tx_role": "node",
          "channel_type": "subscription",
          "wellKnown_Tx": meta:eci
        }
      })
    }
  }

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    // Autoapprove above request
    fired {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }

  rule clear_heartbeat {
    select when gossip clear_heartbeat
    foreach schedule:list().filter(function(scheduled_event) {
      scheduled_event{["event", "domain"]} == "gossip" && scheduled_event{["event", "type"]} == "heartbeat"
    }) setting (scheduled_event)
    fired {
      schedule:remove(scheduled_event{id});
    }
  }

  rule reset_heartbeat {
    select when gossip reset_heartbeat
    fired {
      raise gossip event "clear_heartbeat";
      raise gossip event "heartbeat"
    }
  }

  rule set_heartbeat {
    select when gossip set_heartbeat
    pre {
      interval = event:attr("interval").defaultsTo(ent:interval.defaultsTo(10)).as("Number")
    }
    fired {
      ent:interval := interval;
    }
  }

  rule heartbeat {
    select when gossip heartbeat
    // Base heartbeat rule described in lab.
    pre {
      // Randomly rumor or update state.
      type = random:integer(1)
      eci = getPeer()
      body = (type == 0) => makeRumor(ent:peers{engine:getPicoIDByECI(eci)}.defaultsTo({})) | makeSeen()
    }
    if ent:turnedOn && eci != null && body != {} then
    every {
      // Use send function created earlier.
      send(eci, body, type == 0 => "rumor" | "seen");
    }
    always {
      // Make next heartbeat rule.
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:interval.defaultsTo(10)})
    }
  }

  rule create_rumor {
    select when gossip create_rumor
    fired {
      // Add rumor to entitiy. The 'Rumor' rule will handle the rest
      ent:rumors{[meta:picoId, ent:currentSequence]} := {
        "MessageID": meta:picoId + ":" + ent:currentSequence,
        "SensorID": event:attr("SensorID"),
        "Temperature": event:attr("Temperature"),
        "Timestamp": time:now()
      };
      ent:peers{[meta:picoId, meta:picoId]} := ent:currentSequence;
      // Updating the sequence is important too.
      ent:currentSequence := ent:currentSequence.as("Number") + 1;
    }
  }

  rule rumor {
    select when gossip rumor
    pre {
      message = event:attr("message")
      message_ids = message{"MessageID"}.split(":")
      pico_id = message_ids[0]
      sequence_number = message_ids[1].as("Number")
      receiving_eci = event:attr("eci")
      receiving_pico_id = engine:getPicoIDByECI(receiving_eci)
    }
    fired {
      // Set entities on update
      ent:rumors{[pico_id, sequence_number]} := message if pico_id != "null";
      ent:peers{[pico_id, pico_id]} := sequence_number if pico_id != "null";
      ent:peers{[meta:picoId, pico_id]} := sequence_number if pico_id != "null";
      ent:peers{[receiving_pico_id, pico_id]} := sequence_number if pico_id != "null";
    }
  }

  rule seen {
    select when gossip seen
    pre {
      trash = event:attr("message")
    }
    every {
      // Use helper function
      send(event:attr("eci"), makeRumor(event:attr("message")), "rumor");
    }
  }

  rule toggle_process {
    select when gossip toggle_execution
    // Switch turned-on state.
    send_directive("say", {"state": ent:turnedOn => "off" | "on"})
    fired {
      ent:turnedOn := not ent:turnedOn;
    }
  }
}
