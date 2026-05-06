# typed: false
# frozen_string_literal: true

require "test_helper"

class IdHostEnvTest < ActiveSupport::TestCase
  def setup
    @original_env = {
      "ID_SERVICE_URL" => ENV["ID_SERVICE_URL"],
      "ID_CORPORATE_URL" => ENV["ID_CORPORATE_URL"],
      "ID_STAFF_URL" => ENV["ID_STAFF_URL"],
    }
  end

  def teardown
    @original_env.each do |key, value|
      ENV[key] = value
    end
  end

  test "service_url returns ID_SERVICE_URL" do
    ENV["ID_SERVICE_URL"] = "http://id.app.localhost"

    assert_equal "http://id.app.localhost", IdHostEnv.service_url
  end

  test "corporate_url returns ID_CORPORATE_URL" do
    ENV["ID_CORPORATE_URL"] = "http://id.com.localhost"

    assert_equal "http://id.com.localhost", IdHostEnv.corporate_url
  end

  test "staff_url returns ID_STAFF_URL" do
    ENV["ID_STAFF_URL"] = "http://id.org.localhost"

    assert_equal "http://id.org.localhost", IdHostEnv.staff_url
  end

  test "validate! raises error when env is missing" do
    ENV["ID_SERVICE_URL"] = nil
    ENV["ID_CORPORATE_URL"] = "present"
    ENV["ID_STAFF_URL"] = "present"

    error =
      assert_raises(IdHostEnv::MissingHostError) do
        IdHostEnv.validate!
      end
    assert_match(/Missing required id host env: ID_SERVICE_URL/, error.message)
  end

  test "validate! does not raise error when all env are present" do
    ENV["ID_SERVICE_URL"] = "present"
    ENV["ID_CORPORATE_URL"] = "present"
    ENV["ID_STAFF_URL"] = "present"

    assert_nothing_raised do
      IdHostEnv.validate!
    end
  end
end
