# typed: false
# frozen_string_literal: true

require "test_helper"

class CpuWorkersTest < ActiveSupport::TestCase
  test "prefers PARALLEL_WORKERS when it is a positive integer" do
    assert_equal 6, detect_workers(
      env: { "PARALLEL_WORKERS" => "6" }, host_os: "linux", capture: ->(*) {
        flunk("capture should not be called")
      },
    )
  end

  test "uses lscpu on Linux" do
    capture =
      ->(command) do
        assert_equal "lscpu", command
        "Core(s) per socket: 4\nSocket(s): 2\n"
      end

    assert_equal 8, detect_workers(host_os: "linux-gnu", capture:)
  end

  test "uses sysctl on macOS" do
    capture =
      ->(*command) do
        assert_equal ["sysctl", "-n", "hw.physicalcpu"], command
        "12\n"
      end

    assert_equal 12, detect_workers(host_os: "darwin23.4.0", capture:)
  end

  test "uses sysctl on BSD" do
    capture =
      ->(*command) do
        assert_equal ["sysctl", "-n", "hw.physicalcpu"], command
        "8\n"
      end

    assert_equal 8, detect_workers(host_os: "freebsd13.2", capture:)
  end

  test "falls back to Etc.nprocessors when detection fails" do
    Etc.stub(:nprocessors, 7) do
      assert_equal 7, detect_workers(host_os: "linux", capture: ->(*) { })
    end
  end

  test "returns at least 1 when the fallback is invalid" do
    Etc.stub(:nprocessors, 0) do
      assert_equal 1, detect_workers(host_os: "linux", capture: ->(*) { })
    end
  end

  test "ignores non-positive PARALLEL_WORKERS values" do
    Etc.stub(:nprocessors, 9) do
      assert_equal 9, detect_workers(env: { "PARALLEL_WORKERS" => "0" }, host_os: "linux", capture: ->(*) { })
    end
  end

  private

  def detect_workers(env: {}, host_os: "", capture: ->(*) { })
    CpuWorkers.detect(env:, host_os:, capture:)
  end
end
