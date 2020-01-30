require './db.rb'
require 'securerandom'

def checkTrigger(project_id, trigger_type, replacements, match_data)
  triggers = Trigger.where(project_id: project_id, trigger_on: trigger_type, paused: false)

  # for each trigger found, make a job that fires immediately
  triggers.each do |trigger|
    #puts "checking trigger: #{trigger}"
    conditions = TriggerCondition.where(trigger_id: trigger.id)

    should_trigger = true # "did every condition match?" make it false if any condition failed to match        

    flag = false # did /this/ condition match?

    # assume pass on no conditions
    if (conditions.size == 0)
      flag = true
    end
    
    conditions.each do |condition|
      #puts "CONDITION CHECK STARTED vvvvv ---------------------"
      #puts "checking trigger condition: key: #{condition.match_key} val: #{condition.match_value}"
      match_data.each do |match|
        #puts "SANITY CHECK: #{condition.match_key} == #{match[0]}"
        if condition.match_key == match[0] # is this condition related to this trigger?
          if condition.match_type == "csv" 
            condition.match_value.split(",").each do |csv_condition|
              #puts "CHECKING CSV MATCH: #{match[1]} == #{csv_condition}"
              if match[1] == csv_condition
                flag = true
              end
            end
          elsif condition.match_type == "regex"
            #puts "CHECKING REGEX: #{match[1]} === #{condition.match_value}"
            if !!(match[1] =~ Regexp.new(condition.match_value)) # boolean check if regex matches
              flag = true
            end
          else
            # more match types?
          end
        end
      end # end each match_data
      #puts "CONDITION CHECK ENDED ^^^^^^  ----------------------"
    end # end each-condition

    if (flag == false) # a condition did not match, we should not trigger the job
      #puts "A condition did not match, not triggering"
      should_trigger = false
    else
      #puts "all conditions matched, should be running job"
      should_trigger = true
    end

    if (should_trigger)
      #puts "Setting up job"
      # do shell replacements
      real_cmd = trigger.run_shell
      replacements.each do |replacer|
        real_cmd = real_cmd.gsub(replacer[0].to_s, replacer[1].to_s)
      end

      real_cmd = real_cmd.gsub("%rand7%", SecureRandom.hex[0..7]) # also replace rand7
      #puts "cmd to run: #{real_cmd}"

      # create the job
      db_job = Job.create!(
        user_id: trigger.user_id,
        project_id: project_id,
        job_type: "TOOL",
        job_data: real_cmd,
        run_every: 0,
        last_run: 0,
        max_runtimes: 1,
        status: "queued",
        run_times: 0,
        run_in_background: trigger.run_in_background
      )

      # notify_project("danger", "Triggered: #{trigger.name}")
    end
  end # end each trigger
end # end checkTrigger

def update_host_feed(db_host, source_plugin, header, value )
  db_feed_item = FeedItem.create!(
    host_id: db_host.id,
    source_plugin: source_plugin,
    header: header,
    value: value
  )
  db_feed_item.save 
end

def update_dns_record_feed(db_dns_record, source_plugin, header, value)
  db_feed_item = FeedItem.create!(
    dns_record_id: db_dns_record.id,
    source_plugin: source_plugin,
    header: header,
    value: value
  )
  db_feed_item.save 
end
