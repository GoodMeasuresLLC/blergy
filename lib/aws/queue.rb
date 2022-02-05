module Blergy
  module AWS
    class Queue < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes=hash.to_h.merge(instance.client.describe_queue(instance_id: instance.connect_instance_id, queue_id: hash['id']).queue)
      end

      def modules_dir
        "#{instance.target_directory}/environments/production/queues"
      end

      def terraform_resource_name
        "aws_connect_queue"
      end

      <<-DOC
{:id=>"005be438-2a23-42ee-853d-4e2fd9489f26",
 :arn=>"arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/queue/005be438-2a23-42ee-853d-4e2fd9489f26",
 :name=>"University of Southern California",
 :queue_type=>"STANDARD",
 :queue_arn=>"arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/queue/005be438-2a23-42ee-853d-4e2fd9489f26",
 :queue_id=>"005be438-2a23-42ee-853d-4e2fd9489f26",
 :description=>"AHEAD-University of Southern California",
 :outbound_caller_config=>{:outbound_caller_id_name=>"AHEAD Study", :outbound_caller_id_number_id=>"7e769b74-c31e-4d77-8695-2eb8a2f749a9"},
 :hours_of_operation_id=>"a5e8980e-99e5-4c93-9518-9bc780b69b9b",
 :status=>"ENABLED",
 :tags=>{}}
      DOC
      def write_templates
        FileUtils.mkpath(modules_dir)
        hours_of_operation = instance.hours_of_operation_by_id_for(attributes[:hours_of_operation_id])
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
          resource "#{terraform_resource_name}" "#{label}" {
            description  = "#{attributes[:description]}"
            hours_of_operation_id = "${#{hours_of_operation.terraform_id}}"
            instance_id  = "${${instance.terraform_id}"
          TEMPLATE
          f.write "max_contacts = #{attributes[:max_contacts]}" if attributes[:max_contacts]
          f.write <<-TEMPLATE
            name         = "#{name}"
          TEMPLATE
          if(attributes[:outbound_caller_config])
            arr = [
              "outbound_caller_config {"
            ]
            arr.push("outbound_caller_id_name=#{attributes[:outbound_caller_config][:outbound_caller_id_name]}") if attributes[:outbound_caller_config][:outbound_caller_id_name]
            arr.push("outbound_caller_id_number_id=#{attributes[:outbound_caller_config][:outbound_caller_id_number_id]}") if attributes[:outbound_caller_config][:outbound_caller_id_number_id]
            contact_flow = instance.contact_flow_by_id_for(attributes[:outbound_caller_config][:outbound_flow_id])
            if contact_flow
              arr.push("outbound_flow_id=${#{contact_flow.terraform_id}}")
            end
            arr.push("}")
            f.write arr.join("\n")
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
        contact_flow = instance.contact_flow_by_id_for(attributes[:quick_connect_config][:user_config][:contact_flow_id])
        puts "write_user_config: #{name}: missing contact_flow #{attributes[:quick_connect_config][:user_config][:contact_flow_id]} #{attributes[:quick_connect_config][:user_config]}" unless contact_flow
        f.write <<-TEMPLATE
        user_config {
          contact_flow_id = "#{contact_flow&.terraform_id}"
          user_id = "#{attributes[:quick_connect_config][:user_config][:user_id]}"
        }
        TEMPLATE
      end

      def write_phone_number_config(f)
        f.write <<-TEMPLATE
        phone_config {
          phone_number = "#{attributes[:quick_connect_config][:phone_config][:phone_number]}"
        }
        TEMPLATE
      end

      def write_queue_config(f)
        contact_flow = instance.client.contact_flow_by_id_for(attributes[:quick_connect_config][:queue_config][:contact_flow_id])
        puts "write_queue_config: #{name}: missing contact_flow #{attributes[:quick_connect_config][:queue_config][:contact_flow_id]}"
        queue = instance.client.queue_by_id_for(attributes[:quick_connect_config][:queue_config][:queue_id])
        puts "#{name}: missing queue #{attributes[:quick_connect_config][:queue_config][:queue_id]}"

        f.write <<-TEMPLATE
        queue_config {
          contact_flow_id = "#{contact_flow&.terraform_id}"
          queue_id = "#{queue&.terraform_id}"
        }
        TEMPLATE
      end

      def self.read(instance)
        instance.queues={}
        instance.with_rate_limit do |client|
          client.list_queues(instance_id: instance.connect_instance_id).queue_summary_list.each do |hash|
            next unless hash.name
            instance.with_rate_limit do
              instance.queues[hash.arn]=self.new(instance, hash)
            end
          end
        end
      end
    end
  end
end
