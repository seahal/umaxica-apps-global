# typed: false
# frozen_string_literal: true

require "test_helper"

# The checkpoint page is rendered from the ticket's own view of what is still
# missing, and the age-restricted page is keyed by surface. The surface lookup
# is closed: a surface with no message registered stops the request by name
# rather than rendering an empty page to someone who was just refused.
class SignUpCheckpointRenderSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include SignUpSequenceControllerSupport

    attr_accessor :missing, :pending_actor, :surface, :rendered, :response_double

    def sign_up_missing_requirements = missing

    def sign_up_pending_actor = pending_actor

    def sign_up_surface = surface

    def response
      @response_double ||= Struct.new(:headers).new({})
    end

    def render(*args, **kwargs)
      self.rendered = [args, kwargs]
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.surface = :app
    @harness.missing = [:birthdate]
    @harness.pending_actor = :actor
    @harness.instance_variable_set(
      :@sign_up_ticket,
      Struct.new(:completed_requirements).new([:email]),
    )
  end

  test "the checkpoint page carries what is still missing and what is already cleared" do
    @harness.invoke(:render_sign_up_checkpoint)

    assert_equal [[:show], { status: :ok }], @harness.rendered
    assert_equal [:birthdate], @harness.instance_variable_get(:@sign_up_missing_requirements)
    assert_equal [:email], @harness.instance_variable_get(:@sign_up_completed_requirements)
    assert_equal :actor, @harness.instance_variable_get(:@sign_up_pending_actor)
  end

  test "a cleared requirement that still leaves work returns to the checkpoint" do
    @harness.invoke(:continue_after_cleared_sign_up_requirement)

    assert_equal [[:show], { status: :ok }], @harness.rendered
  end

  test "a surface with no age-restricted message registered is refused by name" do
    @harness.surface = :net

    error = assert_raises(ArgumentError) { @harness.invoke(:render_sign_up_age_restricted) }

    assert_match(/Unknown sign_up_surface/, error.message)
  end
end
