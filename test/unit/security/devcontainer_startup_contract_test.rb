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
      assert_equal ["/home/global/workspace/.devcontainer/tailscale-core-supervisor.sh", "bin/dev"],
                   custom_core.fetch("command")
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
      assert_not custom_core.key?("networks")
      assert_equal "${TAILSCALE_SERVE_HOST:-}",
                   custom_core.fetch("environment").fetch("TAILSCALE_SERVE_HOST")
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

      assert_not custom_services.key?("tailscale-codex")
      assert_not custom_compose.fetch("networks", {}).key?("remote-access")
      assert_not custom_compose.fetch("volumes").key?("tailscale-codex-state")
    end

    test "the Cloudflare sidecar contract remains independent from direct core Tailscale" do
      custom_compose = YAML.unsafe_load_file(Rails.root.join("compose.custom.yaml"))
      cloudflare = custom_compose.fetch("services").fetch("cloudflare-tunnel")

      assert_equal "cloudflare/cloudflared:2025.7.0", cloudflare.fetch("image")
      assert_equal "tunnel --protocol quic run", cloudflare.fetch("command")
      assert_equal "${CLOUDFLARED_TOKEN:?CLOUDFLARED_TOKEN must be set in .env}",
                   cloudflare.fetch("environment").fetch("TUNNEL_TOKEN")
      assert_equal ["frontend"], cloudflare.fetch("networks")
      assert_equal "unless-stopped", cloudflare.fetch("restart")
    end

    test "the supervisor preserves bin dev and starts Tailscale in userspace mode" do
      supervisor = Rails.root.join(".devcontainer/tailscale-core-supervisor.sh").read

      assert_includes supervisor, 'setsid "$@" &'
      assert_includes supervisor, 'kill -TERM -- "-${leader_pid}"'
      assert_includes supervisor, "--tun=userspace-networking"
      assert_includes supervisor, "MAX_TAILSCALED_RESTARTS=3"
      assert_includes supervisor, "remote access is degraded but local development remains available"
      assert_includes supervisor, "install_login_environment || true"
      assert_not_includes supervisor, "/dev/net/tun"
      assert_not(/TS_AUTH(?:KEY|_KEY)/.match?(supervisor))
    end

    test "Tailscale SSH login shells recover the core environment without bootstrap credentials" do
      profile = Rails.root.join(".devcontainer/tailscale-core-login-environment.sh").read

      assert_includes profile, 'if [ -z "${BASH_VERSION:-}" ]'
      assert_includes profile, "read -r -d '' assignment"
      assert_includes profile, "< /proc/1/environ"
      assert_includes profile, "TS_AUTH* | TAILSCALE_AUTH*"
      assert_includes profile, "TUNNEL_TOKEN* | CLOUDFLARED_TOKEN*"
      assert_includes profile, '[[ -n "${SSH_CONNECTION:-}"'
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
      assert_includes dockerfile, "openssh-client"
      assert_not_includes dockerfile, "openssh-server"
    end

    test "the development entrypoint does not operate a second SSH server" do
      entrypoint = Rails.root.join("docker/core/entrypoint.sh").read

      assert_not_includes entrypoint, "REMOTE_SSHD"
      assert_not_includes entrypoint, "/usr/sbin/sshd"
    end
  end
end
