class LandingController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_authenticated_user, only: [ :index ]

  def index
  end

  def test
  end

  def test_cuisines
    # Test with actual cuisine categories from Nasi Goreng Wong Canggu restaurant
    raw_cuisines = [ "bakmie", "ayam & bebek", "aneka nasi" ]

    @original_cuisines = raw_cuisines
    @translated_cuisines = CuisineTranslationService.translate_array(raw_cuisines)

    render json: {
      original: @original_cuisines,
      translated: @translated_cuisines,
      status: "Translation service working correctly!",
      restaurant: "Nasi Goreng Wong Canggu"
    }
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
