# typed: false
# frozen_string_literal: true

require "test_helper"

# Cancelling a step-up hands control back to the identity authority of the same
# surface. Sending a staff cancellation to the end-user authority would post a
# staff ceremony's CSRF token to a different origin, so the mapping is closed:
# a surface outside the three raises rather than picking one.
class SignVerificationCancellationUrlTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ApplicationController
    include SignVerificationCancellation

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    # `*_url` helpers resolve their protocol through the request; the harness is
    # not serving one, so a test request stands in for it.
    @harness.request = ActionDispatch::TestRequest.create
  end

  test "each surface cancels against the identity authority of its own surface" do
    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
                 URI.parse(@harness.invoke(:acme_step_up_cancellation_url_for, "app")).host
    assert_equal ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
                 URI.parse(@harness.invoke(:acme_step_up_cancellation_url_for, "com")).host
    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"),
                 URI.parse(@harness.invoke(:acme_step_up_cancellation_url_for, "org")).host
  end

  test "a surface outside the three is refused rather than mapped to one of them" do
    assert_raises(NotImplementedError) do
      @harness.invoke(:acme_step_up_cancellation_url_for, "net")
    end
  end
end
