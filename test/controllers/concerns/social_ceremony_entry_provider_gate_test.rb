# typed: false
# frozen_string_literal: true

require "test_helper"

# A social ceremony may only start for a provider the surface actually serves.
# Starting one for anything else would issue a ceremony grant naming a provider
# the callback cannot verify, so the request is aborted before any grant exists.
class SocialCeremonyEntryProviderGateTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ActionController::Base
    include SocialCeremonyEntry

    attr_accessor :params_hash, :providers, :redirected

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def social_ceremony_providers = providers

    def social_ceremony_abort_path = "/sign/in"

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.providers = %w(google apple)
  end

  test "a provider this surface does not serve aborts the ceremony before it starts" do
    @harness.params_hash = { provider: "entra", intent: "login" }

    assert_not @harness.invoke(:prepare_social_ceremony!)
    assert_equal [["/sign/in"], {}], @harness.redirected
  end
end
