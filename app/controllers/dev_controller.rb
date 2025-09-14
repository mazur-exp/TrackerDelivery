class DevController < ApplicationController
  allow_unauthenticated_access
  layout false  # Отключаем Rails layout для dev страниц

  def test
  end

  def dashboard
  end

  def onboarding
  end
end
