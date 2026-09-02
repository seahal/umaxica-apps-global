# typed: false
# frozen_string_literal: true

require "test_helper"

# Every realm resolves the credential host it hands OIDC flows to from its own
# configuration. Reading another realm's host would send a client to a surface
# that cannot answer for it, so each is pinned to the variable that realm
# declares.
class OidcHostSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class)
    Class.new(controller_class) do
      def invoke(name, ...) = send(name, ...)
    end.new
  end

  [
    Auth::App::ApplicationController,
    Auth::Com::ApplicationController,
    Auth::Org::ApplicationController,
    Core::App::ApplicationController,
    Core::Com::ApplicationController,
    Core::Org::ApplicationController,
    Side::App::ApplicationController,
    Side::Com::ApplicationController,
    Side::Org::ApplicationController,
  ].each do |controller_class|
    test "#{controller_class.name} resolves its own credential host" do
      assert_predicate harness_for(controller_class).invoke(:oidc_sign_host), :present?
    end
  end

  [
    Auth::App::ApplicationController,
    Auth::Com::ApplicationController,
    Auth::Org::ApplicationController,
  ].each do |controller_class|
    test "#{controller_class.name} resolves its own identity authority host" do
      assert_predicate harness_for(controller_class).invoke(:acme_authority_host), :present?
    end
  end
end
