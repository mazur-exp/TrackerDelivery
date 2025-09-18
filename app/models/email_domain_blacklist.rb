class EmailDomainBlacklist < ApplicationRecord
  validates :domain, presence: true, uniqueness: { case_sensitive: false }

  # Normalize domain to lowercase
  normalizes :domain, with: ->(d) { d.strip.downcase }

  class << self
    def blacklisted?(email_address)
      return false if email_address.blank?

      domain = extract_domain(email_address)
      return false if domain.blank?

      exists?(domain: domain.downcase)
    end

    def extract_domain(email_address)
      return nil if email_address.blank?

      email_address.split("@").last&.strip&.downcase
    end

    def add_domain(domain, reason = nil)
      domain = domain.strip.downcase.gsub(/^@/, "") # Remove @ prefix if present

      create!(
        domain: domain,
        reason: reason || "Automatically blacklisted"
      )
    rescue ActiveRecord::RecordNotUnique
      find_by(domain: domain)
    end

    # Seed common spam/temp email domains
    def seed_common_blacklist!
      common_temp_domains = %w[
        10minutemail.com
        guerrillamail.com
        mailinator.com
        yopmail.com
        temp-mail.org
        throwaway.email
        discard.email
        tempmail.dev
        mohmal.com
        tempail.com
        sharklasers.com
        grr.la
        guerrillamailblock.com
      ]

      common_temp_domains.each do |domain|
        add_domain(domain, "Temporary email provider")
      end
    end
  end
end
