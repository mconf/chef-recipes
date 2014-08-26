# encoding: UTF-8

class Reboot < Chef::Handler # rubocop:disable Documentation
  def initialize
  end

  def report
    return unless run_status.success?
    return unless node.roles.include? node['reboot-handler']['enabled_role']
    return unless node.run_state['reboot']
    unless node['reboot-handler']['post_boot_runlist'].empty?
      node.run_list.reset! node['reboot-handler']['post_boot_runlist']
      node.save
    end

    Mixlib::ShellOut.new(node['reboot-handler']['command']).run_command
  end
end
