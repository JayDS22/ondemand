# frozen_string_literal: true

require 'test_helper'
require 'smart_attributes'

module SmartAttributes
  class AutoWallclockLimitTest < ActiveSupport::TestCase
    test 'initialize default' do
      attribute = SmartAttributes::AttributeFactory.build('auto_wallclock_limit')
      assert_equal({ min: 1, step: 1 }, attribute.opts)
      assert_equal('auto_wallclock_limit', attribute.id)
      assert_equal('1', attribute.value)
      assert_equal('number_field', attribute.widget)
      assert_equal('Walltime Limit', attribute.label)
      assert attribute.required
    end

    test 'initialize with options' do
      attribute = SmartAttributes::AttributeFactory.build('auto_wallclock_limit', { value: 4, label: 'Max Hours' })
      assert_equal({ min: 1, step: 1, value: 4, label: 'Max Hours' }, attribute.opts)
      assert_equal('4', attribute.value)
      assert_equal('Max Hours', attribute.label)
    end

    test 'submit emits wall_time in seconds' do
      attribute = SmartAttributes::AttributeFactory.build('auto_wallclock_limit', { value: 2 })
      assert_equal({ script: { wall_time: 7200 } }, attribute.submit)
    end

    test 'queues emit floored-hour clamp data for queues with finite max_time' do
      Rails.cache.clear
      queue_stubs = [
        stub(name: 'short',     max_time: 3600,       allow_qos: [], deny_qos: [], allow_accounts: nil, deny_accounts: []),
        stub(name: 'long',      max_time: 7 * 86_400, allow_qos: [], deny_qos: [], allow_accounts: nil, deny_accounts: []),
        stub(name: 'unlimited', max_time: nil,        allow_qos: [], deny_qos: [], allow_accounts: nil, deny_accounts: []),
        stub(name: 'oddfloor',  max_time: 7199,       allow_qos: [], deny_qos: [], allow_accounts: nil, deny_accounts: [])
      ]
      Configuration.stubs(:job_clusters).returns([stub(id: 'owens')])
      SmartAttributes::AttributeFactory.stubs(:queues_per_cluster).returns('owens' => queue_stubs)
      SmartAttributes::AttributeFactory.stubs(:accounts).returns(
        [stub(name: 'u1', cluster: 'owens', to_s: 'u1', qos: [])]
      )

      tuples = SmartAttributes::AttributeFactory.queues

      short_data     = tuples.find { |t| t[0] == 'short'     }&.last
      long_data      = tuples.find { |t| t[0] == 'long'      }&.last
      unlimited_data = tuples.find { |t| t[0] == 'unlimited' }&.last
      oddfloor_data  = tuples.find { |t| t[0] == 'oddfloor'  }&.last

      assert_equal 1,   short_data['data-max-auto-wallclock-limit']
      assert_equal 168, long_data['data-max-auto-wallclock-limit']
      refute unlimited_data.key?('data-max-auto-wallclock-limit')
      assert_equal 1,   oddfloor_data['data-max-auto-wallclock-limit']
    end
  end
end
