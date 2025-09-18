require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_session_url
    assert_response :success
  end

  test "should redirect to root after logout when not logged in" do
    delete logout_url
    assert_redirected_to root_url
  end
end
