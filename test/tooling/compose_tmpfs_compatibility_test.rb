# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class ComposeTmpfsCompatibilityTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)
  COMPOSE_FILES = [
    "compose.yaml",
    "compose.override.yaml.example",
  ].freeze

  # Podman 6 rejects numeric uid/gid tmpfs options before the container starts, so a
  # mount written that way fails at `up` rather than at review. Use the `U` option,
  # which assigns the tmpfs to the image's own user, or omit ownership entirely.
  def test_no_tmpfs_mount_sets_ownership_by_numeric_id
    each_tmpfs_mount do |compose_file, service, mount|
      options = mount.split(":", 2).fetch(1, "")

      # assert_nil rather than a refute_/assert_no_ matcher: this file is a plain
      # Minitest::Test, so it has neither Rails' assert_no_match nor the RuboCop
      # rule that rewrites refute_match into it.
      assert_nil(
        options[/\b(?:uid|gid)=/],
        "#{compose_file}: #{service} mounts #{mount}, and Podman 6 refuses to start a " \
        "container whose tmpfs carries a numeric uid or gid option",
      )
    end
  end

  private

  def each_tmpfs_mount
    COMPOSE_FILES.each do |compose_file|
      path = File.join(REPOSITORY_ROOT, compose_file)
      next unless File.exist?(path)

      compose = YAML.safe_load_file(path, aliases: true)

      compose.fetch("services", {}).each do |service, definition|
        next unless definition.is_a?(Hash)

        Array(definition["tmpfs"]).each { |mount| yield compose_file, service, mount }
      end
    end
  end
end
