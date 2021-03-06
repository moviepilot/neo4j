module Neo4j
  module Rule
    class EventListener
      class << self
        # ----------------------------------------------------------------------------------------------------------------
        # Event handling methods
        # ----------------------------------------------------------------------------------------------------------------

        def on_relationship_created(rel, *)
          trigger_start_node = Rule.trigger?(rel._start_node)
          trigger_end_node   = Rule.trigger?(rel._end_node)
          Rule.trigger_rules(rel._start_node) if trigger_start_node
          Rule.trigger_rules(rel._end_node) if trigger_end_node
        end

        def on_property_changed(node, *changes)
          Rule.trigger_rules(node, *changes) if Rule.trigger?(node)
        end

        def on_node_deleted(node, old_properties, data)
          # have we deleted a rule node ?
          del_rule_node = Rule.find_rule_node(node)
          del_rule_node && del_rule_node.clear_rule_node
          return if del_rule_node

          # do we have prop_aggregations for this
          clazz     = old_properties['_classname']
          rule_node = Rule.rule_node_for(clazz)
          return if rule_node.nil?

          id = node.getId
          rule_node.rules.each do |rule|
            next if rule.functions.nil?
            rule_name         = rule.rule_name.to_s

            # is the rule node deleted ?
            deleted_rule_node = data.deletedNodes.find { |n| n == rule_node.rule_node }
            next if deleted_rule_node

            rule.functions.each do |function|
              next unless data.deletedRelationships.find do |r|
                r.getEndNode().getId() == id && r.rel_type == rule_name
              end
              previous_value = old_properties[function.function_id]
              function.delete(rule_name, rule_node.rule_node, previous_value) if previous_value
            end if rule.functions
          end
        end

        def on_neo4j_started(*)
          Rule.on_neo4j_started
        end
      end


    end
    Neo4j.unstarted_db.event_handler.add(EventListener) unless Neo4j.read_only?

  end
end
