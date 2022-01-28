module Blergy
  module AWS
    class Queue < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes=hash.to_h.merge(instance.client.describe_queue(instance_id: instance.connect_instance_id, queue_id: hash['id']).queue)
      end

      def modules_dir
        "#{instance.target_directory}/modules/connect/queues"
      end

      def terraform_resource_name
        "aws_connect_queue"
      end

      <<-DOC
resp.queue.name #=> String
resp.queue.queue_arn #=> String
resp.queue.queue_id #=> String
resp.queue.description #=> String
resp.queue.outbound_caller_config.outbound_caller_id_name #=> String
resp.queue.outbound_caller_config.outbound_caller_id_number_id #=> String
resp.queue.outbound_caller_config.outbound_flow_id #=> String
resp.queue.hours_of_operation_id #=> String
resp.queue.max_contacts #=> Integer
resp.queue.status #=> String, one of "ENABLED", "DISABLED"
resp.queue.tags #=> Hash
resp.queue.tags["TagKey"] #=> String
      DOC
      def write_templates
        FileUtils.mkpath(modules_dir)
        hours_of_operation = instance.hours_of_operation_for(attribute["hours_of_operation_id"])
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
          resource "#{terraform_resource_name}" "#{label}" {
            description  = "#{attributes["description"]}"
            hours_of_operation_id = "#{hours_of_operation.terraform_id}"
            instance_id  = "${aws_connect_instance.connect.id}"
          TEMPLATE
          f.write "max_contacts = #{attribute["max_contacts"]}" if attribute["max_contacts"]
          f.write <<-TEMPLATE
            name         = "#{name}"
          TEMPLATE
          if(attributes["outbound_caller_config"])
            arr = [
              "outbound_caller_config {"
            ]
            arr.push("outbound_caller_id_name=#{attributes["outbound_caller_config"]["outbound_caller_id_name"]}") if attributes["outbound_caller_config"]["outbound_caller_id_name"]
            arr.push("outbound_caller_id_number_id=#{attributes["outbound_caller_config"]["outbound_caller_id_number_id"]}") if attributes["outbound_caller_config"]["outbound_caller_id_number_id"]
            contact_flow = instance.contact_flow_for(attributes["outbound_caller_config"]["outbound_flow_id"])
            if contact_flow
              arr.push("outbound_flow_id=#{contact_flow.terraform_id}")
            end
            arr.push("}")
            f.write << arr.join("\n")
          end
          # quick_connect_ids ??? one or more? or, never happens?
          f.write <<-TEMPLATE
            }
            tags = local.tags
          }
          TEMPLATE
        end
      end

      def write_user_config(f)
        contact_flow = instance.contact_flow_for(attributes["quick_connect_config"]["user_config"]["contact_flow_id"])
        puts "#{name}: missing contact_flow #{attributes["quick_connect_config"]["user_config"]["contact_flow_id"]}"
        f.write <<-TEMPLATE
        user_config {
          contact_flow_id = "#{contact_flow&.terraform_id}"
          user_id = "#{attributes["quick_connect_config"]["user_config"]["user_id"]}"
        }
        TEMPLATE
      end

      def write_phone_number_config(f)
        f.write <<-TEMPLATE
        phone_config {
          phone_number = "#{attributes["quick_connect_config"]["phone_config"]["phone_number"]}"
        }
        TEMPLATE
      end

      def write_queue_config(f)
        contact_flow = instance.contact_flow_for(attributes["quick_connect_config"]["queue_config"]["contact_flow_id"])
        puts "#{name}: missing contact_flow #{attributes["quick_connect_config"]["queue_config"]["contact_flow_id"]}"
        queue = instance.queue_for(attributes["quick_connect_config"]["queue_config"]["queue_id"])
        puts "#{name}: missing contact_flow #{attributes["quick_connect_config"]["queue_config"]["queue_id"]}"

        f.write <<-TEMPLATE
        queue_config {
          contact_flow_id = "#{contact_flow&.terraform_id}"
          queue_id = "#{queue&.terraform_id}"
        }
        TEMPLATE
      end

      def self.read(instance)
        instance.queues={}
        instance.client.list_queues(instance_id: instance.connect_instance_id).queue_summary_list.each do |hash|
          instance.queues[hash.name]=self.new(instance, hash)
        end
      end
    end
  end
end
