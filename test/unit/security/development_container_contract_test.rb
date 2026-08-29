# frozen_string_literal: true

require "test_helper"

class DevelopmentContainerContractTest < ActiveSupport::TestCase
  REPOSITORY_ROOT = Rails.root
  CONFIGURATION_FILES = %w(compose.yaml compose.custom.yaml).freeze

  test "repository uses Containerfile build definitions exclusively" do
    dockerfiles = `git ls-files '*Dockerfile*'`.lines.map(&:strip).reject(&:empty?)

    assert_empty dockerfiles, "repository-owned Dockerfiles: #{dockerfiles.join(", ")}"
    assert_predicate REPOSITORY_ROOT.join("Containerfile"), :file?
  end

  test "local secrets are excluded from Git and both build contexts" do
    assert system("git", "check-ignore", "--quiet", ".secrets/contract-probe")

    %w(.containerignore .dockerignore).each do |path|
      patterns = REPOSITORY_ROOT.join(path).read.lines.map(&:strip)

      assert_includes patterns, ".secrets/", "#{path} must exclude .secrets/"
    end
  end

  test "compose configuration excludes forbidden host and privilege shortcuts" do
    configuration = CONFIGURATION_FILES.filter_map do |path|
      file = REPOSITORY_ROOT.join(path)
      file.read if file.exist?
    end.join("\n")

    forbidden = {
      "host credential mount" => %r{source:\s*["']?\$\{HOME[^\n]*(?:\.ssh|\.gnupg|\.config/(?:gh|opencode)|\.claude|\.codex|\.gitconfig)},
      "SSH agent forwarding" => /SSH_AUTH_SOCK/,
      "container engine socket" => %r{(?:docker|podman)\.sock},
      "privileged mode" => /^\s*privileged:\s*true\s*$/,
      "host networking" => /^\s*network_mode:\s*host\s*$/,
      "explicit shared memory size" => /^\s*shm_size:/,
    }

    forbidden.each do |description, pattern|
      assert_no_match pattern, configuration, description
    end
  end

  test "Containerfiles do not declare or copy credentials" do
    containerfiles = Dir.glob(REPOSITORY_ROOT.join("**/Containerfile"))
    credential_name = /(?:PASSWORD|SECRET|TOKEN|API_KEY|PRIVATE_KEY|AUTH_SOCK)/i

    containerfiles.each do |path|
      contents = File.read(path)

      assert_not contents.lines.any? { |line| line.match?(/^\s*(?:ARG|ENV)\s+.*#{credential_name}/) }, path
      assert_no_match(/^\s*COPY\s+.*(?:\.secrets|\.ssh|\.gnupg|\.config\/(?:gh|opencode)|\.claude|\.codex)/i, contents, path)
    end
  end

  test "devcontainer uses the standard CLI lifecycle without a repository launcher" do
    devcontainer = REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read

    assert_not_predicate REPOSITORY_ROOT.join("podman/tools/dcup"), :exist?
    assert_not_includes devcontainer, "ensure-shared-networks"
    assert_not_includes devcontainer, "initializeCommand",
                        "the stack provisions its own credentials through the `dev-credentials` " \
                        "service, so no host-side bootstrap script may run before the build"
  end

  test "the development container bakes one pinned Tailscale and no supervisor scripts" do
    containerfile = REPOSITORY_ROOT.join("Containerfile").read

    assert_match(/tailscale=\d+\.\d+\.\d+/, containerfile,
                 "`core` joins the tailnet itself now, so the client is an image dependency " \
                 "and must be version-pinned the way the sidecar image's digest used to be")
    assert_includes containerfile, "pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg",
                    "the apt repository must be signed by Tailscale's own key, not trusted"
    assert_includes containerfile,
                    "RUN cat > /usr/local/bin/tailscale <<'WRAPPER' && chmod 0555 /usr/local/bin/tailscale",
                    "the bare CLI dials a root tailscaled this container cannot run; the " \
                    "wrapper is what makes `tailscale up` work in a development shell, and " \
                    "0555 root ownership keeps the workspace bind from rewriting it"

    assert_not_includes REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read, "tailscale",
                        "joining the tailnet stays opt-in; devcontainer.json must not arrange it"

    # `.devcontainer/` holds configuration only. Every script the image needs is
    # written from a Containerfile heredoc instead, so nothing the developer can
    # edit in the workspace decides what a privileged path executes, and the
    # directory stays comparable with umaxica-apps-edge.
    assert_empty Dir.glob("*.sh", base: REPOSITORY_ROOT.join(".devcontainer")),
                 "shell scripts under .devcontainer/ must move into the Containerfile"

    # The supervisor/status/login-environment trio was an earlier in-container
    # attempt, which ran tailscaled from shell hooks nothing owned. The wrapper's
    # start-on-first-use replaced it; reintroducing any of them would mean two
    # things start the same daemon on the same socket.
    %w(
      .devcontainer/tailscale-core-supervisor.sh
      .devcontainer/tailscale-core-status.sh
      .devcontainer/tailscale-core-login-environment.sh
      .devcontainer/tailscale-serve.json
    ).each do |path|
      assert_not_predicate REPOSITORY_ROOT.join(path), :exist?
    end
  end

  test "the Tailscale wrapper starts a user-space daemon and never asks for privilege" do
    contents = REPOSITORY_ROOT.join("Containerfile").read[/<<'WRAPPER'[^\n]*\n(.*?)\nWRAPPER\n/m, 1]

    assert contents, "the Containerfile no longer writes a tailscale wrapper"
    # Comments are stripped: the file explains at length why root is unavailable
    # here, and prose must not be able to satisfy -- or break -- an assertion.
    code = contents.lines.reject { |line| line.lstrip.start_with?("#") }.join

    assert_includes contents, "--tun=userspace-networking",
                    "kernel mode would need /dev/net/tun and NET_ADMIN, which is exactly the " \
                    "privilege the sidecar was built to avoid requesting"
    assert_no_match(/\bsudo\b|\bsu -/, code,
                    "there is no sudo in this image and no root to escalate to")
    assert_includes contents, "exec /usr/bin/tailscale",
                    "beyond starting the daemon the wrapper must be a pass-through, or the " \
                    "CLI's own behaviour becomes this repository's to maintain"
  end

  test "compose network external flags are booleans rather than interpolated strings" do
    compose_files = ["compose.yaml", "compose.custom.yaml"]

    compose_files.each do |relative_path|
      contents = REPOSITORY_ROOT.join(relative_path).read

      assert_no_match(/^\s*external:\s*["']?\$\{/i, contents, relative_path)
    end
  end

  test "the tunnel connector joins only the Rails frontend network" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    connector_networks = connector.fetch("networks")

    assert_includes connector_networks, "frontend",
                    "a service-level networks: list in an overlay replaces the base list rather " \
                    "than merging with it, so removing frontend here silently detaches the " \
                    "connector from the private *.localhost Rails origins"
    assert_equal ["frontend"], connector_networks
    assert_not overlay.fetch("networks", {}).key?("edge-tunnel"),
               "Edge reaches Rails through Workers VPC; the repositories must not share a " \
               "host Podman network"
    assert_not connector.key?("extra_hosts"),
               "the connector reaches Rails over its private Podman network; a host-gateway " \
               "alias unnecessarily expands the origins reachable from the tunnel sidecar"
  end

  test "the tunnel connector can identify the tunnel it is asked to run" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    argv = connector.fetch("command").split

    assert_equal "${CLOUDFLARED_TOKEN:?CLOUDFLARED_TOKEN must be set in .env}",
                 connector.fetch("environment").fetch("TUNNEL_TOKEN")
    assert_equal "run", argv.last
    assert_includes argv, "run", "the connector must still run a tunnel"
  end

  test "the tunnel connector uses a supported pinned cloudflared release" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")

    assert_equal "docker.io/cloudflare/cloudflared:2026.8.2", connector.fetch("image")
  end

  test "no service restarts without a bound" do
    %w(compose.yaml compose.custom.yaml).each do |relative_path|
      compose = YAML.safe_load_file(REPOSITORY_ROOT.join(relative_path), aliases: true)

      compose.fetch("services", {}).each do |name, service|
        next unless service.is_a?(Hash) && service.key?("restart")

        assert_not_equal "unless-stopped", service.fetch("restart"),
                         "#{relative_path}: #{name} would restart forever with no Podman " \
                         "backoff, turning a startup misconfiguration into a restart storm"
      end
    end
  end

  test "the tunnel connector caps what a crash loop can consume" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")

    %w(cpus mem_limit pids_limit logging).each do |key|
      assert connector.key?(key),
             "cloudflare-tunnel declares no #{key}, so a crash loop is bounded only by the host"
    end

    assert_not connector.key?("profiles"),
               "the always-merged development overlay must start its authenticated connector " \
               "during the standard Dev Container lifecycle"
  end

  test "the tunnel token comes only from the gitignored repository environment file" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    services = overlay.fetch("services")

    assert system("git", "check-ignore", "--quiet", ".env")
    assert_not connector.key?("volumes")
    assert_not services.key?("cloudflared-login")
    assert_not services.key?("cloudflared-credentials")
    assert_not_includes overlay.fetch("volumes", {}).keys, "cloudflared-credentials"
  end

  test "PostgreSQL health checks authenticate through the runtime writer secret" do
    compose = REPOSITORY_ROOT.join("compose.yaml").read

    assert_operator compose.scan('export PGPASSWORD="$$(cat "$${POSTGRES_PASSWORD_FILE}")"').length,
                    :>=,
                    2
  end

  # Development service passwords are generated inside the stack rather than on the
  # host: `bin/setup-dev-secrets` and its Podman Secret registration are gone, so a
  # fresh clone needs no bootstrap command. The invariant that replaces "every
  # mounted secret is provisioned" is that every service reading a credential path
  # both mounts the volume read-only and waits for the generator to finish.
  test "every service reading a development credential gates on the generator" do
    compose = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.yaml"), aliases: true)
    services = compose.fetch("services")

    assert_not compose.key?("secrets"),
               "Podman Secrets required a host-side registration step; credentials now come " \
               "from the `dev-credentials` volume"

    generator = services.fetch("dev-credentials")

    assert_equal [ "dev-credentials:/credentials" ], generator.fetch("volumes"),
                 "the generator is the only writer, so it is the only service mounting the " \
                 "volume read-write"

    readers = services.reject { |name, _| name == "dev-credentials" }.select do |_, service|
      service.is_a?(Hash) && service.to_yaml.include?("/run/dev-credentials/")
    end

    assert_equal %w(core primary replica rustfs), readers.keys.sort

    readers.each do |name, service|
      mount = Array(service["volumes"]).find do |entry|
        case entry
        when String then entry.start_with?("dev-credentials:")
        when Hash then entry["source"] == "dev-credentials"
        end
      end

      assert mount, "#{name} reads /run/dev-credentials but mounts no credential volume"

      read_only = mount.is_a?(String) ? mount.end_with?(":ro") : mount.fetch("read_only", false)

      assert read_only,
             "#{name} could rewrite a credential the databases have already baked into their " \
             "data volumes"

      assert_equal "service_completed_successfully",
                   service.fetch("depends_on").fetch("dev-credentials").fetch("condition"),
                   "#{name} would start against an empty credential file"
    end
  end
  test "no Tailscale sidecar returns, under any compose file" do
    (CONFIGURATION_FILES + [".devcontainer/compose.override.yml"]).each do |path|
      file = REPOSITORY_ROOT.join(path)
      next unless file.exist?

      services = YAML.safe_load_file(file, aliases: true).fetch("services", {})

      assert_not services.key?("tailscale"),
                 "#{path} declares a `tailscale` service; the daemon belongs inside `core`, " \
                 "and a second one would race it for the same node identity"
    end
  end
  test "the docker and podman control-plane trees stay byte-identical" do
    %w(core/entrypoint.sh).each do |relative_path|
      assert_equal REPOSITORY_ROOT.join("podman", relative_path).read,
                   REPOSITORY_ROOT.join("docker", relative_path).read,
                   "docker/#{relative_path} drifted from the podman/ copy the image is built from"
    end
  end
  test "RustFS credentials are mounted files rather than Compose interpolation" do
    compose = REPOSITORY_ROOT.join("compose.yaml").read

    assert_includes compose,
                    "OBJECT_STORAGE_ACCESS_KEY_ID_FILE: /run/dev-credentials/rustfs-access-key"
    assert_includes compose,
                    "OBJECT_STORAGE_SECRET_ACCESS_KEY_FILE: /run/dev-credentials/rustfs-secret-key"
    assert_no_match(
      /^\s*(?:OBJECT_STORAGE_(?:ACCESS_KEY_ID|SECRET_ACCESS_KEY)|RUSTFS_(?:ACCESS_KEY|SECRET_KEY|RPC_SECRET)):\s*["']?\$\{/,
      compose,
      "object-storage credentials must not come from .env interpolation",
    )
  end
end
