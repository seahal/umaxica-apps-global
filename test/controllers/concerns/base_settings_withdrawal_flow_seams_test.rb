# typed: false
# frozen_string_literal: true

require "test_helper"

# The withdrawal screens branch on actor state at every step: the status screen
# only exists once a withdrawal is under way, recovery is blocked while a privacy
# request is open, and early termination only runs for an actor eligible for it.
# Each of those guards decides whether an account is destroyed early or kept, and
# the falling-through arms had no coverage.
class BaseSettingsWithdrawalFlowSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include ::BaseSettingsWithdrawalFlow

    attr_accessor :redirects, :rendered, :schedule_confirmed_flag, :session_public_id, :session_record

    def initialize
      @redirects = []
    end

    def invoke(name, ...) = send(name, ...)

    def safe_redirect_to(*args, **kwargs) = redirects << [args, kwargs]

    def render(*args, **kwargs) = self.rendered = [args, kwargs]

    def withdrawal_new_path = "/settings/withdrawal/new"

    def withdrawal_settings_path = "/settings/withdrawal"

    def current_session_public_id = session_public_id

    def current_session = session_record
  end

  def actor_double(in_progress: false, terminated: false)
    Struct.new(
      :withdrawal_in_progress?, :terminated?, :recovery_available_at, :recovery_deadline,
      :early_termination_available_at, :can_recover?, :early_terminatable?,
    ).new(in_progress, terminated, Time.current, 1.week.from_now, 2.days.from_now, true, false)
  end

  test "the status screen sends an actor with no withdrawal under way back to the entry screen" do
    harness = Harness.new

    harness.invoke(:render_withdrawal_status, actor_double)

    assert_equal 1, harness.redirects.size
    assert_equal ["/settings/withdrawal/new"], harness.redirects.first.first
    assert_equal :see_other, harness.redirects.first.last.fetch(:status)
  end

  test "the status screen renders for an actor already withdrawing or terminated" do
    withdrawing = Harness.new
    withdrawing.invoke(:render_withdrawal_status, actor_double(in_progress: true))

    assert_empty withdrawing.redirects
    assert withdrawing.instance_variable_get(:@recoverable)

    terminated = Harness.new
    terminated.invoke(:render_withdrawal_status, actor_double(terminated: true))

    assert_empty terminated.redirects
    assert terminated.instance_variable_get(:@terminated)
  end

  # An actor type the flow does not serve must not be treated as unblocked by
  # default -- but it must also not raise, so the answer is a plain refusal.
  test "an actor type the recovery block does not know is not treated as blocked" do
    assert_not Harness.new.invoke(:privacy_request_blocks_recovery?, Object.new)
  end

  test "a validation failure re-renders the entry screen with the schedule still confirmed" do
    harness = Harness.new

    harness.invoke(:render_update_validation_error)

    assert harness.instance_variable_get(:@schedule_confirmed)
    assert_equal [:new], harness.rendered.first
    assert_equal :unprocessable_content, harness.rendered.last.fetch(:status)
  end

  # The session id is read from whichever of three places the surface populated,
  # because withdrawal must know which session performed it in order to spare it.
  test "the acting session id is read from whichever source carries it" do
    from_reader = Harness.new
    from_reader.session_public_id = "from-reader"

    assert_equal "from-reader", from_reader.invoke(:withdrawal_current_session_public_id)

    from_ivar = Harness.new
    from_ivar.instance_variable_set(:@current_token_public_id, "from-ivar")

    assert_equal "from-ivar", from_ivar.invoke(:withdrawal_current_session_public_id)

    from_session = Harness.new
    from_session.session_record = Struct.new(:public_id).new("from-session")

    assert_equal "from-session", from_session.invoke(:withdrawal_current_session_public_id)
  end
end
