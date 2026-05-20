# typed: false
# frozen_string_literal: true

require "action_push_native"

action_push_native_root = Gem.loaded_specs.fetch("action_push_native").full_gem_path
require File.join(action_push_native_root, "app/models/action_push_native/record.rb")
require File.join(action_push_native_root, "app/models/action_push_native/device.rb")
