class Current < ActiveSupport::CurrentAttributes
  attribute :session
  
  delegate :user, to: :session, allow_nil: true
  
  def user_signed_in?
    user.present?
  end
  
  def user_email
    user&.email_address
  end
  
  def user_name
    user&.display_name
  end
end