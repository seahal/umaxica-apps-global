# typed: false
# frozen_string_literal: true

require "test_helper"
require "json"
require "yaml"

module Security
  class DevcontainerStartupContractTest < ActiveSupport::TestCase
    test "Dev Containers preserve the repository entrypoint and bin dev command" do
      source = Rails.root.join(".devcontainer/devcontainer.json").read
      devcontainer = JSON.parse(source.gsub(/^\s*\/\/.*$/, ""))
      base_compose = YAML.unsafe_load_file(Rails.root.join("compose.yaml"))
      custom_compose = YAML.unsafe_load_file(Rails.root.join("compose.custom.yaml"))
      base_core = base_compose.fetch("services").fetch("core")
      custom_core = custom_compose.fetch("services").fetch("core")

      assert_not devcontainer.fetch("overrideCommand")
      assert_equal ["/bin/bash", "/home/global/workspace/docker/core/entrypoint.sh"],
                   base_core.fetch("entrypoint")
      assert_equal ["bin/dev"], base_core.fetch("command")
      assert_not custom_core.key?("command")
    end

    test "the direct core node uses userspace Tailscale without elevated container privileges" do
      override_compose = YAML.unsafe_load_file(
        Rails.root.join(".devcontainer/compose.override.yml"),
      )
      custom_compose = YAML.unsafe_load_file(Rails.root.join("compose.custom.yaml"))
      override_core = override_compose.fetch("services").fetch("core")
      custom_services = custom_compose.fetch("services")
      custom_core = custom_services.fetch("core")

      assert_not_includes override_core.fetch("environment"), "REMOTE_SSHD=1"
      assert_equal ["3000:3000", "3036:3036"], override_core.fetch("ports")
      assert_equal({}, custom_core.fetch("networks").fetch("remote-access"))
      assert_not custom_core.key?("environment")
      assert_equal ["/home/global/workspace/.devcontainer/tailscale-core-supervisor.sh", "bin/dev"],
                   custom_core.fetch("command")
      assert_not custom_services.key?("tailscale-core-tools")
      assert_not custom_core.key?("cap_add")
      assert_not custom_core.key?("devices")
      assert_not custom_core.key?("privileged")

      state_mount = custom_core.fetch("volumes").sole

      assert_equal "volume", state_mount.fetch("type")
      assert_equal "tailscale-core-state", state_mount.fetch("source")
      assert_equal "/var/lib/tailscale-core", state_mount.fetch("target")

      sidecar = custom_services.fetch("tailscale-codex")

      assert_equal ["remote-access"], sidecar.fetch("networks")
      assert_equal "/etc/tailscale/serve/serve.json",
                   sidecar.fetch("environment").fetch("TS_SERVE_CONFIG")
    end

    test "the supervisor preserves bin dev and starts Tailscale in userspace mode" do
      supervisor = Rails.root.join(".devcontainer/tailscale-core-supervisor.sh").read

      assert_includes supervisor, 'setsid "$@" &'
      assert_includes supervisor, 'kill -TERM -- "-${leader_pid}"'
      assert_includes supervisor, "--tun=userspace-networking"
      assert_includes supervisor, "MAX_TAILSCALED_RESTARTS=3"
      assert_includes supervisor, "remote access is degraded but local development remains available"
      assert_not_includes supervisor, "/dev/net/tun"
      assert_not(/TS_AUTH(?:KEY|_KEY)/.match?(supervisor))
    end

    test "Tailscale binaries are pinned and copied only into the development target" do
      dockerfile = Rails.root.join("Dockerfile").read
      production_target = dockerfile.index("FROM production-base AS production")
      development_target = dockerfile.index("FROM development-base AS development")
      tailscale_copy = dockerfile.index(
        "COPY --from=tailscale-toolchain /usr/local/bin/tailscale /usr/local/bin/tailscale",
      )

      assert_includes dockerfile,
                      "tailscale/tailscale:v1.98.9@sha256:6dba149843cfd9171bbd602b17a71b0fb7955c13f96f534877075c915abbc072"
      assert_operator tailscale_copy, :>, development_target
      assert_operator tailscale_copy, :>, production_target
    end
  end
end
