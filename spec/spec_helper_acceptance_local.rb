# frozen_string_literal: true

require 'singleton'
require 'serverspec'
require 'puppetlabs_spec_helper/module_spec_helper'
include PuppetLitmus

RSpec.configure do |c|
  c.mock_with :rspec
  c.before :suite do
    # Ensure the metrics collector classes are applied
    pp = <<-PUPPETCODE
    include puppet_metrics_collector
    class {'puppet_metrics_collector::system':
      manage_sysstat => true,
    }
    PUPPETCODE

    PuppetLitmus::PuppetHelpers.apply_manifest(pp)

    # Download the plugins to ensure up-to-date facts
    PuppetLitmus::PuppetHelpers.run_shell('/opt/puppetlabs/bin/puppet plugin download')
    # Put a test PE license in place, set its ownership and permissions
    mylicensefile = <<~EOF
      #######################
      #  Begin License File #
      #######################
      # PUPPET ENTERPRISE LICENSE - Puppet Labs
      to: test
      nodes: 100
      license_type: Subscription
      support_type: PE Premium
      start: 2014-02-10
      end: 2028-06-13
      #####################
      #  End License File #
      #####################
      EOF

    PuppetLitmus::PuppetHelpers.write_file(mylicensefile, '/etc/puppetlabs/license.key')
    PuppetLitmus::PuppetHelpers.run_shell('sudo chown root:root /etc/puppetlabs/license.key')
    PuppetLitmus::PuppetHelpers.run_shell('sudo chmod 644 /etc/puppetlabs/license.key')
    # restarting puppet server to clear jruby stats for S0019
    PuppetLitmus::PuppetHelpers.run_shell('puppet resource service pe-puppetserver ensure=stopped; puppet resource service pe-puppetserver ensure=running')
    # Wait for the puppetserver to fully come online before running the tests
    timeout = <<-TIME
    timeout 300 bash -c 'while [[ "$(curl -s -k -o /dev/null -w ''%{http_code}'' https://127.0.0.1:8140/status/v1/simple)" != "200" ]]; do sleep 5; done' || false
    TIME
    PuppetLitmus::PuppetHelpers.run_shell(timeout)
    # Ensure there is no running agent process and default to a disabled agent
    PuppetLitmus::PuppetHelpers.run_shell('puppet resource service puppet ensure=stopped; puppet agent --disable; puppet resource service puppet ensure=running;')
  end
end
