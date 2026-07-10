# frozen_string_literal: true

require "test_helper"

class ModelLoadTest < ActiveSupport::TestCase
  test "all model files load successfully" do
    model_files = Rails.root.glob("app/models/**/*.rb")
    model_files.each do |file|
      relative_path = file.to_s.sub("#{Rails.root.join("app/models/")}", "").sub(/\.rb$/, "")
      relative_path = relative_path.sub("concerns/", "") if relative_path.start_with?("concerns/")
      class_name = relative_path.camelize
      begin
        klass = class_name.constantize

        assert defined?(klass), "#{class_name} should be defined"
      rescue NameError => e
        flunk("Failed to constantize #{class_name} from #{relative_path}: #{e.message}")
      end
    end
  end
end
