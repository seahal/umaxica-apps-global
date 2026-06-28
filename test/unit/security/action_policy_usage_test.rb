# typed: false
# frozen_string_literal: true

require "test_helper"

class ActionPolicyUsageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SURFACE_AUTHORIZATION_CONTEXTS = {
    Auth::App::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Auth::Com::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Auth::Org::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Base::App::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Base::Com::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Base::Org::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Core::App::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Core::Com::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Core::Org::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Side::App::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Side::Com::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Side::Org::ApplicationController => { actor: :current_actor, user: :current_policy_user },
  }.freeze

  test "authenticated surface controllers use Action Policy with explicit actor context" do
    SURFACE_AUTHORIZATION_CONTEXTS.each do |controller_class, expected_context|
      assert_includes controller_class.ancestors,
                      ActionPolicy::Controller,
                      "#{controller_class.name} must include ActionPolicy::Controller"
      assert_equal(
        expected_context,
        controller_class.instance_variable_get(:@authorization_targets),
        "#{controller_class.name} must configure Action Policy actor and compatibility user contexts",
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
