# typed: false
# frozen_string_literal: true

require "test_helper"

# Erasure requests are scoped to the subject's own table, and the jurisdiction
# they are filed under is taken from a request parameter. A subject type this
# surface does not serve must stop the request by name rather than silently
# reading the wrong table, and a jurisdiction outside the recognised set is
# recorded as unknown rather than stored as given.
class PrivacyErasureRequestFlowGuardsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ActionController::Base
    include PrivacyErasureRequestFlow

    attr_accessor :params_hash, :rendered

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def render(*args, **kwargs)
      self.rendered = [args, kwargs]
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a subject type this flow does not serve is refused by name" do
    error = assert_raises(ArgumentError) { @harness.invoke(:privacy_requests_for, Operator.new) }

    assert_match(/unsupported privacy erasure subject/, error.message)
  end

  test "a recognised jurisdiction is kept and anything else is recorded as unknown" do
    known = PrivacyRequestState::JURISDICTIONS.first
    @harness.params_hash = { jurisdiction: known }

    assert_equal known, @harness.invoke(:privacy_erasure_jurisdiction)

    @harness.params_hash = { jurisdiction: "not-a-jurisdiction" }

    assert_equal "unknown", @harness.invoke(:privacy_erasure_jurisdiction)

    @harness.params_hash = {}

    assert_equal "unknown", @harness.invoke(:privacy_erasure_jurisdiction)
  end

  test "a forbidden erasure request is answered as plain text without a page" do
    @harness.invoke(:render_privacy_erasure_forbidden)

    assert_equal [[], { plain: I18n.t("privacy_erasure.forbidden"), status: :forbidden }], @harness.rendered
  end
end
