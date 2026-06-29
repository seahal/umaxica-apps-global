# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::Dev::RootsControllerTest < ActionDispatch::IntegrationTest
  test "renders the React Aria probe mount point on the developer host" do
    host! ENV.fetch("PRIVATE_CORE_DEVELOPER_URL", "core.dev.localhost")

    get core_developer_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Core Dev React Aria Probe"
    assert_select "[data-react-component='ReactAriaProbe']"
  end
end
