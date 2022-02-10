class Hash
  def each_with_parent(parent=nil, &blk)
    each do |k, v|
      case
      when v.kind_of?(Hash) then v.each_with_parent(k, &blk)
      when v.kind_of?(Array)
        if v.first.kind_of?(Hash)
          v.each { |ele| ele.each_with_parent(nil, &blk) }
        else
          blk.call([parent, self, k, v])
        end
      else
        blk.call([parent, self, k, v])
      end
    end
  end
  def deep_clone
    Marshal.load(Marshal.dump(self))
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
        fred=content.deep_clone
        fred.each_with_parent do |parent, hash, k, v|
          next unless parent
          if parent.downcase =~ /contact-flow|contactflow|contactflowid/ && v.to_s =~ /arn:/
            contact_flow = instance.contact_flow_by_id_for(hash["id"])
            if contact_flow
              hash["id"] = "${#{contact_flow&.terraform_reference}}"
              hash["text"] = "#{contact_flow&.name}"
            end
          elsif parent.downcase =~ /queue|customerqueue|queueid/ && v.to_s =~ /arn:/
            queue = instance.queue_for(hash["id"])
            if queue
              hash["id"] = "${#{queue&.terraform_reference}}"
              hash["text"] = "#{queue&.name}"
            end
          elsif k == "ContactFlowId" && v.to_s =~ /arn:/
            hash[k]="${#{instance.contact_flow_by_id_for(hash[k]).terraform_reference}}"
          elsif k == "LambdaFunctionARN" && v.to_s =~ /arn:/
            lambda = instance.lambda_function_for(hash[k])
            hash[k]="${#{lambda.terraform_reference}}"
          end
        end
        fred
      end

      def modules_dir
        "#{instance.target_directory}/modules/connect/flows"
      end

      def accessor_name
        :flows
      end

      def terraform_module_name
        "module.connect.module.flows.aws_connect_contact_flow.#{label}"
      end

      def terraform_key
        "contact_flow_id"
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
resource "#{terraform_resource_name}" "#{label}" {
  instance_id  = var.connect_instance_id
  name         = "#{name}"
  type         = "#{attributes[:type]}"
  description  = "#{attributes[:description]}"
  filename     = "${path.module}/#{file_name}"
  content_hash = filebase64sha256("${path.module}/#{file_name}")
  tags = var.tags
}
          TEMPLATE
        end
        File.open("#{modules_dir}/#{file_name}","w") do |f|
          f.write JSON.pretty_generate(variablize_content)
        end
      end

      def self.read(instance)
        instance.flows={}
        instance.with_rate_limit do |client|
          client.list_contact_flows(instance_id: instance.connect_instance_id).contact_flow_summary_list.each do |hash|
# id="0179bac6-241f-461d-b1b0-1d525f8bd6fa",
# arn="arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/contact-flow/0179bac6-241f-461d-b1b0-1d525f8bd6fa",
# name="00 MainPatient Flow - In (Open)",
# contact_flow_type="CONTACT_FLOW"
           # if hash.name =~ /^Sample.*|^ZZ/
           #  `aws connect delete-contact-flow --instance-id #{instance.connect_instance_id} --contact-flow-id #{hash.id}`

           # end
            instance.with_rate_limit do
              instance.flows[hash.arn]=ContactFlow.new(instance, hash)
            end
          end
        end
      end
    end
  end
end

