# encoding: UTF-8

require_relative 'spec_helper'
require File.join File.dirname(__FILE__), '..', 'files', 'default', 'reboot'

describe Reboot do
  Mixlib::ShellOut.class_eval do
    def run_command
      true
    end
  end

  let(:handler) { Reboot.new }
  let(:node) { ChefSpec::Runner.new.converge('reboot-handler::default').node }
  let(:status) do
    Chef::RunStatus.new node, Chef::EventDispatch::Dispatcher.new
  end

  it "doesn't reboot if the run failed" do
    status.exception = Exception.new

    expect(handler.run_report_unsafe(status)).not_to be
  end

  it "doesn't reboot if the node does not have the enabled_role" do
    expect(handler.run_report_unsafe(status)).not_to be
  end

  it "doesn't reboot if the node has the enabled_role, but missing the reboot flag" do # rubocop:disable LineLength
    allow(node).to receive(:roles).and_return ['booted']

    expect(handler.run_report_unsafe(status)).not_to be
  end

  context 'with enabled_role and reboot flag' do
    before do
      allow(node).to receive(:roles).and_return ['booted']
      node.run_state['reboot'] = true
    end

    it 'reboots' do
      expect(handler.run_report_unsafe(status)).to be
    end

    it 'issues correct command' do
      obj = double
      allow(node).to receive(:run_command).and_return true
      allow_any_instance_of(Mixlib::ShellOut).to receive(:new)
        .with('sync; sync; shutdown -r +1&')
        .and_return(obj)
      handler.run_report_unsafe(status)
    end

    it 'resets run_list if node has a post_boot_runlist attribute' do
      node.set['reboot-handler']['post_boot_runlist'] = ['role[foo]']
      allow(node).to receive(:roles).and_return ['booted']
      allow(node).to receive(:save)
      node.run_state['reboot'] = true
      handler.run_report_unsafe(status)

      expect(node.run_list.to_s).to eq 'role[foo]'
    end
  end
end
