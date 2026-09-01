# typed: false
# frozen_string_literal: true

require "test_helper"

# The welcome hand-off page and the activity list are per-surface renderings of
# shared state. The welcome page must offer the surface's own next step, and an
# activity row must be serialised through the presenter so raw column values
# never reach the page.
class WelcomeAndActivitySeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, &definition)
    Class.new(controller_class) do
      attr_accessor :params_hash, :rendered

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  [Base::Com::WelcomesController, Base::Org::WelcomesController].each do |klass|
    test "#{klass.name} offers its own next step on the welcome hand-off" do
      harness = harness_for(klass)
      harness.instance_variable_set(:@welcome_next_path, "/dashboard")

      harness.show

      props = harness.rendered.last.fetch(:props)

      assert_predicate props.fetch(:next_link).fetch(:href), :present?
    end
  end

  [Base::Com::Identity::ActivitiesController, Base::Org::Identity::ActivitiesController].each do |klass|
    test "#{klass.name} serialises an activity row through the presenter" do
      presenter = Object.new
      presenter.define_singleton_method(:occurred_at) { |_activity| Time.zone.local(2026, 9, 1, 12, 0, 0) }
      presenter.define_singleton_method(:event_label) { |_activity| "Signed in" }
      presenter.define_singleton_method(:ip_address) { |_activity| "203.0.113.5" }
      presenter.define_singleton_method(:user_agent_summary) { |_activity| "Chrome" }
      presenter.define_singleton_method(:login_method) { |_activity| "email" }
      presenter.define_singleton_method(:login_method_label) { |_activity| "Email" }
      presenter.define_singleton_method(:context_text) { |_activity| "from Tokyo" }

      harness = harness_for(klass) do
        define_method(:activity_log) { presenter }
      end
      activity = Struct.new(:id, :event_id).new(7, 4)

      row = harness.invoke(:serialize_activity, activity)

      assert_equal "7", row.fetch(:id)
      assert_equal "Signed in", row.fetch(:event_label)
      assert_equal "203.0.113.5", row.fetch(:ip_address)
    end
  end
end
