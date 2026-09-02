# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

# Plain Minitest::Test, like the other tooling guards: it reads Compose YAML and needs no Rails
# environment. That is why the assertions below are Minitest's `refute_*` rather than the
# `assert_not_*` forms RuboCop's Rails/RefuteMethods prefers -- those are ActiveSupport::TestCase
# additions and raise NoMethodError here.
# rubocop:disable Rails/RefuteMethods
class ComposeInitReapingTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)
  COMPOSE_FILES = [
    "compose.yaml",
    "compose.override.yaml.example",
    ".devcontainer/compose.override.yml",
  ].freeze

  # A container's PID 1 inherits every orphaned process and is the only process that can reap
  # them. A PID 1 that never calls wait() leaves them as zombies for the life of the container.
  # These commands do exactly that, so a service running one needs a reaping init at PID 1.
  NON_REAPING_COMMANDS = [
    %w(sleep infinity),
    %w(tail -f /dev/null),
  ].freeze

  # Measured on 2026-08-30 before `init: true` was added to `core`: 80 zombies after 22 hours of
  # uptime (39 git, 14 ruby, 10 bash, 4 Claude CLI, 3 editor server), growing at ~3.7/hour against
  # a 2048 pids limit. The Dev Container is deliberately long-lived, so the leak never resets.
  def test_services_parked_on_a_non_reaping_command_declare_an_init
    parked_services do |compose_file, service, definition|
      assert(
        definition["init"],
        "#{compose_file}: #{service} parks PID 1 on #{Array(definition["command"]).join(" ").inspect}, " \
        "which never reaps orphans; declare `init: true` so a reaping init owns PID 1",
      )
    end
  end

  # The guard above is only meaningful while it actually matches a service. If `core` is ever
  # renamed or its command changes shape, this fails rather than passing vacuously.
  def test_the_guard_covers_at_least_one_service
    matched = []
    parked_services { |_compose_file, service, _definition| matched << service }

    refute_empty(
      matched,
      "no service parks PID 1 on a non-reaping command; if that is now true remove this guard, " \
      "otherwise NON_REAPING_COMMANDS has drifted from compose.yaml",
    )
  end

  private

  def parked_services
    COMPOSE_FILES.each do |compose_file|
      next unless File.exist?(File.join(REPOSITORY_ROOT, compose_file))

      load_compose(compose_file).fetch("services", {}).each do |service, definition|
        next unless definition.is_a?(Hash)
        next unless NON_REAPING_COMMANDS.include?(Array(definition["command"]).map(&:to_s))

        yield compose_file, service, definition
      end
    end
  end

  def load_compose(compose_file)
    YAML.safe_load_file(File.join(REPOSITORY_ROOT, compose_file), aliases: true)
  end
end
# rubocop:enable Rails/RefuteMethods
