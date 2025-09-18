require "test_helper"

class DevControllerTest < ActionDispatch::IntegrationTest
  test "should redirect unauthenticated user to root from dashboard" do
    get dev_dashboard_url
    assert_redirected_to root_url
    assert_match /Please sign in to continue/, flash[:alert]
  end

  test "should redirect unauthenticated user to root from onboarding" do
    get dev_onboarding_url
    assert_redirected_to root_url
    assert_match /Please sign in to continue/, flash[:alert]
  end
end
