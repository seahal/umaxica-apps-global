# typed: false
# frozen_string_literal: true

require "test_helper"

class ControllerSurfaceStructureTest < ActiveSupport::TestCase
  ROOTS = %w(jump sign apex).freeze
  SURFACES = %w(app com org dev net).freeze

  test "jump sign and apex do not keep top-level controller files" do
    offenders =
      ROOTS.flat_map do |root|
        Rails.root.glob("app/controllers/#{root}/*_controller.rb").map do |path|
          Pathname(path).relative_path_from(Rails.root).to_s
        end
      end

    assert_empty offenders
  end

  test "jump sign and apex controller files live under known surface directories" do
    offenders =
      ROOTS.flat_map do |root|
        Rails.root.glob("app/controllers/#{root}/**/*_controller.rb").filter_map do |path|
          relative = Pathname(path).relative_path_from(Rails.root.join("app/controllers")).to_s
          surface = relative.split("/")[1]
          relative unless SURFACES.include?(surface)
        end
      end

    assert_empty offenders
  end

  test "apex developer and network hosts have surface-local controllers" do
    %w(dev net).each do |surface|
      %w(application roots healths csp_violation_reports bare).each do |controller|
        assert_path_exists Rails.root.join("app/controllers/apex", surface, "#{controller}_controller.rb")
      end
    end
  end

  test "jump root redirect controllers inherit from their surface application controllers" do
    assert_operator Jump::App::RootsController, :<, Jump::App::ApplicationController
    assert_operator Jump::Com::RootsController, :<, Jump::Com::ApplicationController
    assert_operator Jump::Org::RootsController, :<, Jump::Org::ApplicationController
  end
end
