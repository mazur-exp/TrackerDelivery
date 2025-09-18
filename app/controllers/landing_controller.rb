class LandingController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_authenticated_user, only: [ :index ]

  def index
  end

  def test
  end

  private

  def redirect_authenticated_user
    return unless authenticated?

    # If user has restaurants configured, redirect to dashboard
    # Otherwise, redirect to onboarding
    if current_user.has_restaurants?
      redirect_to "/dashboard"
    else
      redirect_to "/onboarding"
    end
  end
end
