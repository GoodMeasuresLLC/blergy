class Hash
  def each_with_parent(parent=nil, &blk)
    each do |k, v|
      Hash === v ? v.each_with_parent(k, &blk) : blk.call([parent, self, k, v])
    end
  end
end

module Blergy
  module AWS
    class ContactFlow < Base
      attr_accessor :content

      def initialize(instance, hash)
        self.instance=instance
        instance.client.describe_contact_flow(instance_id: instance.connect_instance_id, contact_flow_id: hash.id).each do |hash|
          self.attributes=hash.contact_flow.to_h
          self.content = JSON.parse(hash.contact_flow.content)
        end
      end

      def variablize_content
        content.each_with_parent do |parent, hash, k, v|
          if parent == 'ContactFlow'
            contact_flow = instance.contact_flow_for(hash["id"])
            hash["id"] = "${#{contact_flow.terraform_id}}"
          end
        end
      end

      def modules_dir
        "#{instance.target_directory}/modules/connect/flows"
      end

      def terraform_resource_name
        "aws_connect_contact_flow"
      end

      def file_name
        "#{label}.json"
      end

      def write_templates
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE

 id="fc7e607a-a89f-45b9-8346-0d9a497d03b1",
 name="0x Inbound to Agent",
 type="CONTACT_FLOW",
 description=nil,

resource "#{terraform_resource_name}" "#{label}" {
  instance_id  = "${aws_connect_instance.connect.id}"
  name         = "#{name}"
  type         = "#{attributes[:type]}"
  description  = "#{attributes[:description]}"
  filename     = "#{file_name}"
  content_hash = filebase64sha256("#{file_name}")
  tags = local.tags
}
          TEMPLATE
        end
        File.open("#{modules_dir}/#{file_name}","w") do |f|
          f.write JSON.pretty_generate(variablize_content)
        end
      end

      def self.read(instance)
        instance.flows={}
        instance.client.list_contact_flows(instance_id: instance.connect_instance_id).contact_flow_summary_list.each do |hash|
# id="0179bac6-241f-461d-b1b0-1d525f8bd6fa",
# arn="arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/contact-flow/0179bac6-241f-461d-b1b0-1d525f8bd6fa",
# name="00 MainPatient Flow - In (Open)",
# contact_flow_type="CONTACT_FLOW"
           # if hash.name =~ /^Sample.*|^ZZ/
           #  `aws connect delete-contact-flow --instance-id #{instance.connect_instance_id} --contact-flow-id #{hash.id}`

           # end
          instance.flows[hash.arn]=ContactFlow.new(instance, hash)
        end
      end
    end
  end
end

