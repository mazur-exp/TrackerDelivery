# frozen_string_literal: true

class AuthChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to auth stream for this session token
    session_token = params[:session_token]

    if session_token.present?
      stream_from "auth_#{session_token}"
      Rails.logger.info "📡 AuthChannel subscribed: #{session_token}"
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
    Rails.logger.info "📡 AuthChannel unsubscribed"
  end
end
