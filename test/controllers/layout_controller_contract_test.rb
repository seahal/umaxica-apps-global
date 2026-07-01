# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutControllerContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CONTROLLERS = {
    "app/controllers/auth/app/application_controller.rb" => ["Auth::App::ApplicationController", "auth/app/application"],
    "app/controllers/auth/com/application_controller.rb" => ["Auth::Com::ApplicationController", "auth/com/application"],
    "app/controllers/auth/org/application_controller.rb" => ["Auth::Org::ApplicationController", "auth/org/application"],
    "app/controllers/base/app/application_controller.rb" => ["Base::App::ApplicationController", "base/app/application"],
    "app/controllers/base/com/application_controller.rb" => ["Base::Com::ApplicationController", "base/com/application"],
    "app/controllers/base/org/application_controller.rb" => ["Base::Org::ApplicationController", "base/org/application"],
    "app/controllers/core/app/application_controller.rb" => ["Core::App::ApplicationController", "core/app/application"],
    "app/controllers/core/com/application_controller.rb" => ["Core::Com::ApplicationController", "core/com/application"],
    "app/controllers/core/org/application_controller.rb" => ["Core::Org::ApplicationController", "core/org/application"],
    "app/controllers/side/app/application_controller.rb" => ["Side::App::ApplicationController", "side/app/application"],
    "app/controllers/side/com/application_controller.rb" => ["Side::Com::ApplicationController", "side/com/application"],
    "app/controllers/side/org/application_controller.rb" => ["Side::Org::ApplicationController", "side/org/application"],
    "app/controllers/palm/app/application_controller.rb" => ["Palm::App::ApplicationController", "palm/app/application"],
  }.freeze

  test "application controllers declare literal layouts" do
    CONTROLLERS.each do |path, (controller_name, layout_name)|
      contents = Rails.root.join(path).read
      controller = controller_name.safe_constantize

      assert_predicate controller, :present?
      assert_equal layout_name, controller._layout
      assert_includes contents, %(layout "#{layout_name}"), "missing literal layout declaration in #{path}"
      assert_not_match(/\blayout\s*(?:->|do|proc|lambda|method)/, contents,
                       "layout declaration in #{path} must stay literal")
    end
  end

  test "palm only has an app surface" do
    assert defined?(Palm::App::ApplicationController)
    assert_not defined?(Palm::Com::ApplicationController)
    assert_not defined?(Palm::Org::ApplicationController)
    assert_predicate Rails.root.join("app/views/layouts/palm/app/application.html.erb"), :exist?
    assert_not_predicate Rails.root.join("app/views/layouts/palm/com"), :exist?
    assert_not_predicate Rails.root.join("app/views/layouts/palm/org"), :exist?
  end
end
