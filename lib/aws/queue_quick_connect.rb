module Blergy
  module AWS
    class QueueQuickConnect < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes=hash.to_h.merge(instance.client.describe_quick_connect(instance_id: instance.connect_instance_id, quick_connect_id: hash['id']).quick_connect)
      end

      def terraform_key
        "queue_quick_connect_id"
      end

      def accessor_name
        :queue_quick_connects
      end
      def terraform_resource_name
        "aws_connect_quick_connect"
      end
      def modules_dir
        "#{instance.target_directory}/environments/production/queue_quick_connects"
      end
      def write_templates
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          stuff=attributes[:quick_connect_config][:quick_connect_type]
          binding.pry if stuff.nil?
          f.write <<-TEMPLATE
resource "#{terraform_resource_name}" "#{label}" {
	instance_id  = var.connect_instance_id
	name         = "#{name}"
	quick_connect_config {
	  quick_connect_type = "#{stuff}"

              TEMPLATE
              send "write_#{stuff.downcase}_config", f
              f.write <<-TEMPLATE
	}
	tags = var.tags
}
          TEMPLATE
        end
      end

# {:id=>"02d8cd41-a0fd-4b18-8b9d-a10074ae298b",
#  :arn=>"arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/transfer-destination/02d8cd41-a0fd-4b18-8b9d-a10074ae298b",
#  :name=>"Ashley Lahr",
#  :quick_connect_type=>"USER",
#  :quick_connect_arn=>
#   "arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/transfer-destination/02d8cd41-a0fd-4b18-8b9d-a10074ae298b",
#  :quick_connect_id=>"02d8cd41-a0fd-4b18-8b9d-a10074ae298b",
#  :quick_connect_config=>
#   {:quick_connect_type=>"USER", :user_config=>{:user_id=>"6d7295ae-19e3-4c55-991e-00cb034efd79", :contact_flow_id=>"5064b4f2-9652-411e-a338-3bfac5bd33f1"}},
#  :tags=>{}}
      def write_user_config(f)
        # you were here
        # problem is, the query is by ID, not
        # by ARN, which is how stuff is indexed
        contact_flow = instance.contact_flow_by_id_for(attributes[:quick_connect_config][:user_config][:contact_flow_id])
        puts "queue_quick_connect: write_user_config #{name}: missing contact_flow #{attributes[:quick_connect_config][:user_config][:contact_flow_id]}" unless contact_flow
        f.write <<-TEMPLATE
        user_config {
          contact_flow_id = "${#{contact_flow&.terraform_reference}}"
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
        contact_flow = instance.contact_flow_by_id_for(attributes[:quick_connect_config][:queue_config][:contact_flow_id])
        puts "write_queue_config #{name}: missing contact_flow #{attributes[:quick_connect_config][:queue_config][:contact_flow_id]}"
        queue = instance.queue_by_id_for(attributes[:quick_connect_config][:queue_config][:queue_id])
        puts "write_queue_config #{name}: missing queue #{attributes[:quick_connect_config][:queue_config][:queue_id]}"

        f.write <<-TEMPLATE
        queue_config {
          contact_flow_id = "#{contact_flow&.terraform_reference}"
          queue_id = "#{queue&.terraform_id}"
        }
        TEMPLATE
      end

      def self.read(instance)
        instance.queue_quick_connects={}
        instance.with_rate_limit do |client|
          client.list_quick_connects(instance_id: instance.connect_instance_id).quick_connect_summary_list.each do |hash|
            instance.with_rate_limit do |client|
              instance.queue_quick_connects[hash.arn]=self.new(instance, hash)
            end
          end
        end
      end
    end
  end
end
