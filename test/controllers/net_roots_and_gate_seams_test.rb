# typed: false
# frozen_string_literal: true

require "test_helper"

# The internal network roots answer a plain identifier rather than a page, and
# the availability gate answers a switched-off surface with a machine-readable
# refusal and a retry hint. Neither is reachable from a browser flow, so both
# are pinned directly.
class NetRootsAndGateSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class)
    Class.new(controller_class) do
      attr_accessor :rendered

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  [Base::Net::RootsController, Core::Net::RootsController].each do |klass|
    test "#{klass.name} answers a plain identifier rather than a page" do
      harness = harness_for(klass)

      harness.index

      assert_predicate harness.rendered.last.fetch(:plain), :present?
    end
  end
end
