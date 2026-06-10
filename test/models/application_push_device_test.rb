# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: action_push_native_devices
# Database name: com_principal
#
#  id         :bigint           not null, primary key
#  name       :string
#  owner_type :string
#  platform   :string           not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  owner_id   :bigint
#
# Indexes
#
#  index_action_push_native_devices_on_owner  (owner_type,owner_id)
#
require "test_helper"

class ApplicationPushDeviceTest < ActionDispatch::IntegrationTest
  test "ApplicationPushDevice inherits from ActionPushNative::Device" do
    assert_equal "ActionPushNative::Device", ApplicationPushDevice.superclass.name
  end

  test "device class can be referenced" do
    assert_kind_of Class, ApplicationPushDevice
    assert_operator ApplicationPushDevice, :<, ActionPushNative::Device
  end

  test "device has platform enum defined" do
    assert_respond_to ApplicationPushDevice, :platforms
  end

  test "device table exists on the model connection" do
    assert ApplicationPushDevice.lease_connection.data_source_exists?(ApplicationPushDevice.table_name)
  end
end
