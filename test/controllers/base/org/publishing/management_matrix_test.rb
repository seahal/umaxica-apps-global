# frozen_string_literal: true

require "test_helper"

class Base::Org::Publishing::ManagementMatrixTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CELLS = [
    ["app", "info", Base::Org::Publishing::Info::App::EntriesController],
    ["com", "info", Base::Org::Publishing::Info::Com::EntriesController],
    ["org", "info", Base::Org::Publishing::Info::Org::EntriesController],
    ["app", "docs", Base::Org::Publishing::Docs::App::EntriesController],
    ["com", "docs", Base::Org::Publishing::Docs::Com::EntriesController],
    ["org", "docs", Base::Org::Publishing::Docs::Org::EntriesController],
    ["app", "news", Base::Org::Publishing::News::App::EntriesController],
    ["com", "news", Base::Org::Publishing::News::Com::EntriesController],
    ["org", "news", Base::Org::Publishing::News::Org::EntriesController],
    ["app", "help", Base::Org::Publishing::Help::App::EntriesController],
    ["com", "help", Base::Org::Publishing::Help::Com::EntriesController],
    ["org", "help", Base::Org::Publishing::Help::Org::EntriesController],
  ].freeze

  test "all twelve management controllers declare identity and share actions" do
    CELLS.each do |audience, surface, controller|
      assert_includes controller.ancestors, PublishingManagementEntriesActions, controller.name
      assert_equal audience, controller.publishing_audience, controller.name
      assert_equal surface, controller.publishing_surface, controller.name
      assert_equal Publishing::ContentFamilies.entry_class(surface:, audience:), controller::ENTRY_CLASS,
                   controller.name
      assert_operator controller, :<, Base::Org::ApplicationController
      assert_equal :private, controller::AUTHENTICATION_MODE
    end
  end
end
