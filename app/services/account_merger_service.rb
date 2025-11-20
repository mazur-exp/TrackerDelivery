# frozen_string_literal: true

# Service for merging OAuth provider accounts by email
# Implements "one user, multiple auth methods" strategy
class AccountMergerService
  # Find existing user or create new one, linking OAuth provider
  #
  # @param provider [Symbol] :google, :apple, :facebook, :telegram
  # @param provider_id [String] Unique ID from OAuth provider
  # @param email [String, nil] Email from OAuth provider (may be nil)
  # @param attributes [Hash] Additional user attributes (name, picture, etc.)
  # @return [User] Found or created user
  #
  # @example
  #   AccountMergerService.find_or_merge(
  #     provider: :google,
  #     provider_id: "123456789",
  #     email: "user@example.com",
  #     attributes: {
  #       google_email: "user@example.com",
  #       google_picture: "https://..."
  #     }
  #   )
  def self.find_or_merge(provider:, provider_id:, email: nil, attributes: {})
    provider_id_column = "#{provider}_id"

    # Step 1: Try to find by provider ID (exact match)
    user = User.find_by(provider_id_column => provider_id)
    if user
      Rails.logger.info "✅ Found existing user by #{provider}_id: #{provider_id}"
      return user
    end

    # Step 2: If email provided, try to find existing user by email
    if email.present?
      existing_user = User.find_by(email_address: email)

      if existing_user
        # Merge: Add new provider to existing account
        Rails.logger.info "🔗 Merging #{provider} account to existing user: #{email}"

        existing_user.update!(
          provider_id_column => provider_id,
          **attributes
        )

        return existing_user
      end
    end

    # Step 3: Create new user with this provider
    Rails.logger.info "➕ Creating new user with #{provider}: #{email || provider_id}"

    User.create!(
      provider_id_column => provider_id,
      email_address: email,
      **attributes
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ Failed to find or merge user: #{e.message}"
    raise
  end

  # Link additional authentication method to existing user
  #
  # @param user [User] Existing user
  # @param provider [Symbol] :google, :apple, :facebook, :telegram, :email
  # @param provider_id [String] Unique ID from OAuth provider
  # @param attributes [Hash] Additional attributes to update
  # @return [Boolean] Success status
  def self.link_provider(user:, provider:, provider_id:, attributes: {})
    provider_id_column = "#{provider}_id"

    # Check if provider already linked
    if user.send(provider_id_column).present?
      Rails.logger.warn "⚠️  User #{user.id} already has #{provider} linked"
      return false
    end

    # Check if provider ID already used by another user
    if User.where.not(id: user.id).exists?(provider_id_column => provider_id)
      Rails.logger.error "❌ #{provider}_id #{provider_id} already used by another user"
      return false
    end

    # Link provider
    user.update!(
      provider_id_column => provider_id,
      **attributes
    )

    Rails.logger.info "✅ Linked #{provider} to user #{user.id}"
    true
  rescue => e
    Rails.logger.error "❌ Failed to link #{provider}: #{e.message}"
    false
  end

  # Unlink authentication method from user
  # Only allowed if user has multiple auth methods (can't remove last one)
  def self.unlink_provider(user:, provider:)
    unless user.has_multiple_auth_methods?
      Rails.logger.warn "⚠️  Cannot unlink last authentication method for user #{user.id}"
      return false
    end

    provider_id_column = "#{provider}_id"

    user.update!(provider_id_column => nil)

    Rails.logger.info "✅ Unlinked #{provider} from user #{user.id}"
    true
  rescue => e
    Rails.logger.error "❌ Failed to unlink #{provider}: #{e.message}"
    false
  end
end
