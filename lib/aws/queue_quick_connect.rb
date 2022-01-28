module Blergy
  module AWS
    class QueueQuickConnect < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes=hash.to_h.merge(instance.client.describe_quick_connect(instance_id: instance.connect_instance_id, quick_connect_id: hash['id']).quick_connect)
      end

      def terraform_resource_name
        "aws_connect_quick_connect"
      end
      def modules_dir
        "#{instance.target_directory}/modules/connect/quick_connects"
      end
      <<-DOC
      resp.quick_connect.quick_connect_arn #=> String
      resp.quick_connect.quick_connect_id #=> String
      resp.quick_connect.name #=> String
      resp.quick_connect.description #=> String
      resp.quick_connect.quick_connect_config.quick_connect_type #=> String, one of "USER", "QUEUE", "PHONE_NUMBER"
      resp.quick_connect.quick_connect_config.user_config.user_id #=> String
      resp.quick_connect.quick_connect_config.user_config.contact_flow_id #=> String
      resp.quick_connect.quick_connect_config.queue_config.queue_id #=> String
      resp.quick_connect.quick_connect_config.queue_config.contact_flow_id #=> String
      resp.quick_connect.quick_connect_config.phone_config.phone_number #=> String


      quick_connect_config {
        quick_connect_type = "PHONE_NUMBER"

        phone_config {
          phone_number = "+12345678912"
        }
      }

      DOC
      def write_templates
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
          resource "#{terraform_resource_name}" "#{label}" {
            instance_id  = "${aws_connect_instance.connect.id}"
            name         = "#{name}"
            description  = "#{attributes["description"]}"
            quick_connect_config {
              quick_connect_type = "#{attributes["quick_connect_type"]}"

              TEMPLATE
              send "write_#{attributes["quick_connect_type"].downcase}_config", f
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
        instance.quick_connects={}
        instance.client.list_quick_connects(instance_id: instance.connect_instance_id).quick_connect_summary_list.each do |hash|
          instance.quick_connects[hash.name]=self.new(instance, hash)
        end
      end
    end
  end
end
