module Blergy
  module AWS
    class HoursOfOperation < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes=hash.to_h.merge(instance.client.describe_hours_of_operation(instance_id: instance.connect_instance_id, hours_of_operation_id: hash['id']).hours_of_operation)
      end

      def modules_dir
        "#{instance.target_directory}/modules/connect/hours"
      end

      def terraform_module_name
        "module.connect.module.connect_hours.aws_connect_hours_of_operation.#{label}"
      end


      def accessor_name
        :hours_of_operations
      end

      def terraform_key
        "hours_of_operation_id"
      end

      def terraform_resource_name
        "aws_connect_hours_of_operation"
      end

      def write_config_templates(f)
        attributes[:config].each do |config|
          f.write <<-TEMPLATE
  config {
    day = "#{config[:day]}"

    end_time {
      hours   = #{config[:end_time][:hours]}
      minutes = #{config[:end_time][:minutes]}
    }

    start_time {
      hours   = #{config[:start_time][:hours]}
      minutes = #{config[:start_time][:minutes]}
    }
  }
          TEMPLATE
        end
      end

      def write_templates
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
resource "#{terraform_resource_name}" "#{label}" {
  instance_id  = var.connect_instance_id
  name         = "#{name}"
TEMPLATE
          f.write  %Q{  description  = "#{attributes["description"]}"\n} if attributes["description"]
          f.write  %Q{  time_zone  = "#{attributes["time_zone"]||'America/New_York'}"\n}
          write_config_templates(f)
          f.write <<-TEMPLATE
  tags = var.tags
}
          TEMPLATE
        end
      end

      def self.read(instance)
        instance.hours_of_operations={}
        instance.with_rate_limit do |client|
          client.list_hours_of_operations(instance_id: instance.connect_instance_id).hours_of_operation_summary_list.each do |hash|
            instance.with_rate_limit do |client|
              instance.add_hours_of_operation(hash.arn, self.new(instance, hash))
            end
          end
        end
      end
    end
  end
end

