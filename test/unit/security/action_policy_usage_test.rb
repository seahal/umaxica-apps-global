# typed: false
# frozen_string_literal: true

require "test_helper"

class ActionPolicyUsageTest < ActiveSupport::TestCase
  fixtures_none!

  SURFACE_AUTHORIZATION_CONTEXTS = {
    Acme::App::ApplicationController => :current_policy_user,
    Acme::Com::ApplicationController => :current_policy_user,
    Acme::Org::ApplicationController => :current_policy_user,
    Sign::App::ApplicationController => :current_policy_user,
    Sign::Com::ApplicationController => :current_policy_user,
    Sign::Org::ApplicationController => :current_policy_user,
  }.freeze

  test "authenticated surface controllers use Action Policy with explicit user context" do
    SURFACE_AUTHORIZATION_CONTEXTS.each do |controller_class, current_actor_method|
      assert_includes controller_class.ancestors,
                      ActionPolicy::Controller,
                      "#{controller_class.name} must include ActionPolicy::Controller"
      assert_equal(
        { user: current_actor_method },
        controller_class.instance_variable_get(:@authorization_targets),
        "#{controller_class.name} must configure Action Policy user context",
      )
    end
  end

  test "authenticated surface controllers run access policy before actions" do
    SURFACE_AUTHORIZATION_CONTEXTS.each_key do |controller_class|
      before_filters =
        controller_class._process_action_callbacks.filter_map do |callback|
          callback.filter if callback.kind == :before
        end

      assert_includes before_filters,
                      :enforce_access_policy!,
                      "#{controller_class.name} must run access policy enforcement"
      assert(
        controller_class.const_defined?(:AUTHENTICATION_MODE, false) ||
          controller_class.local_authentication_mode_rules.present?,
        "#{controller_class.name} must declare an authentication mode",
      )
    end
  end

  test "application code does not use Pundit" do
    offenders = matching_lines(/\bPundit\b|\bpundit\b/, paths_under("app", "lib", "config"))

    assert_empty offenders, "Use Action Policy only. Remove Pundit references:\n#{offenders.join("\n")}"
  end

  test "application code does not use authorization bypass helpers" do
    offenders = matching_lines(/\bskip_authorization\b|\bskip_policy_scope\b/, paths_under("app", "lib", "config"))

    assert_empty offenders, "Authorization bypass helpers are forbidden:\n#{offenders.join("\n")}"
  end

  private

  def paths_under(*roots)
    roots.flat_map { |root| Rails.root.glob("#{root}/**/*") }.select { |path| File.file?(path) }
  end

  def matching_lines(pattern, paths)
    paths.flat_map do |path|
      relative_path = path.relative_path_from(Rails.root).to_s
      content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

      content.each_line.with_index(1).filter_map do |line, line_number|
        "#{relative_path}:#{line_number}: #{line.strip}" if line.match?(pattern)
      end
    end
  end
end
