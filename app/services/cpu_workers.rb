# typed: false
# frozen_string_literal: true

require "etc"

module CpuWorkers
  module_function

  def detect(env: ENV, host_os: RbConfig::CONFIG["host_os"], capture: method(:`))
    configured = positive_integer(env["PARALLEL_WORKERS"])
    return configured if configured

    detected =
      if host_os.to_s.include?("linux")
        linux_physical_cores(capture)
      elsif host_os.to_s.match?(/darwin|bsd/)
        positive_integer(capture.call("sysctl", "-n", "hw.physicalcpu"))
      end

    detected || [Etc.nprocessors.to_i, 1].max
  end

  def linux_physical_cores(capture)
    output = capture.call("lscpu").to_s
    cores = output[/Core\(s\) per socket:\s*(\d+)/, 1].to_i
    sockets = output[/Socket\(s\):\s*(\d+)/, 1].to_i
    total = cores * sockets

    total.positive? ? total : nil
  end
  private_class_method :linux_physical_cores

  def positive_integer(value)
    integer = Integer(value.to_s, exception: false)
    integer if integer&.positive?
  end
  private_class_method :positive_integer
end
