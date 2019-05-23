require 'capistrano/dsl'

load File.expand_path("../tasks/elbas.rake", __FILE__)

def autoscale(groupname, properties = {})
  include Capistrano::DSL
  include Elbas::Logger

  set :aws_autoscale_group_name, groupname
  group_names = fetch(:group_names, [])
  group_names << groupname
  set :group_names, group_names

  asg = Elbas::AWS::AutoscaleGroup.new groupname
  instances = asg.instances.running

  instances.each.with_index do |instance, i|
    info "Adding server: #{instance.hostname}"

    props = nil
    props = yield(instance, i) if block_given?
    props ||= properties

    server instance.hostname, props
  end

  if instances.any?
    after 'deploy', 'elbas:deploy'
  else
    error <<~MESSAGE
      Could not create AMI because no running instances were found in the specified
      AutoScale group. Ensure that the AutoScale group name is correct and that
      there is at least one running instance attached to it.
    MESSAGE
  end
end
