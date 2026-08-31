# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-up checkpoint page offers the person a second factor to add. Each choice
# carries the ticket's checkpoint_version in its link so a stale tab cannot advance a
# ticket that has already moved on, and both surfaces build the same shape.
class SignUpCheckpointPagePropsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def self.harness_for(concern, surface)
    Class.new do
      include concern

      define_method(:page_t) { |key| "t:#{key}" }

      define_method(:t) { |key, **| "t:#{key}" }

      define_method(:params) { { ri: "jp" }.with_indifferent_access }

      define_method(:signed_pt_param) { "signed-pt" }

      define_method(:surface_name) { surface }

      def invoke(name, ...) = send(name, ...)

      # The concerns name their surface's route helpers directly.
      def method_missing(name, *args, **kwargs)
        return super unless name.to_s.end_with?("_path")

        "#{name}?#{kwargs.map { |k, v| "#{k}=#{v}" }.join("&")}"
      end

      def respond_to_missing?(name, include_private = false)
        name.to_s.end_with?("_path") || super
      end
    end.new
  end

  {
    app: AppSignUpCheckpointPage,
    com: ComSignUpCheckpointPage,
  }.each do |surface, concern|
    test "the #{surface} checkpoint choices carry the ticket's checkpoint version" do
      harness = self.class.harness_for(concern, surface)
      harness.instance_variable_set(:@sign_up_ticket, Struct.new(:checkpoint_version).new(4))

      %i(sign_up_checkpoint_passkey_props sign_up_checkpoint_passcode_props).each do |seam|
        props = harness.invoke(seam)

        assert_predicate props.fetch(:title), :present?, "#{surface} #{seam}"
        assert_predicate props.fetch(:description), :present?, "#{surface} #{seam}"
        assert_predicate props.fetch(:label), :present?, "#{surface} #{seam}"
        assert_match(/checkpoint_version=4/, props.fetch(:href), "#{surface} #{seam}")
        assert_match(/pt=signed-pt/, props.fetch(:href), "#{surface} #{seam}")
      end
    end
  end
end
