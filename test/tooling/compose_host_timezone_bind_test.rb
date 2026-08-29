# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

# /etc/timezone is a Debian/Ubuntu file. Fedora, RHEL, and Arch do not have it, and
# Podman then refuses to start the container:
#   statfs /etc/timezone: no such file or directory
# Compose merges volume entries by container target, so a compose.custom.yaml
# /etc/localtime mount does not replace a distinct /etc/timezone bind in
# compose.yaml.
class ComposeHostTimezoneBindTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  def test_no_compose_file_binds_host_etc_timezone
    offenders = []

    %w(compose.yaml compose.custom.yaml).each do |relative_path|
      path = File.join(REPOSITORY_ROOT, relative_path)
      next unless File.exist?(path)

      compose = YAML.safe_load_file(path, aliases: true)
      compose.fetch("services", {}).each do |service, definition|
        next unless definition.is_a?(Hash)

        Array(definition["volumes"]).each do |mount|
          source, target =
            case mount
            when Hash
              [mount["source"].to_s, mount["target"].to_s]
            when String
              parts = mount.split(":", 3)
              [parts.fetch(0, ""), parts.fetch(1, "")]
            else
              ["", ""]
            end

          next unless source == "/etc/timezone" || target == "/etc/timezone"

          offenders << "#{relative_path} #{service} binds #{source} -> #{target}"
        end
      end
    end

    assert_empty offenders,
                 "/etc/timezone is absent on Fedora/RHEL/Arch. Bind /etc/localtime instead; " \
                 "Compose will not drop a distinct /etc/timezone target when an overlay adds " \
                 "/etc/localtime."

    custom = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.custom.yaml"),
      aliases: true,
    )
    localtime_binds =
      Array(custom.fetch("services").fetch("core")["volumes"]).select do |mount|
        mount.is_a?(Hash) && mount["source"] == "/etc/localtime" && mount["target"] == "/etc/localtime"
      end

    assert_equal 1, localtime_binds.size
  end
end
