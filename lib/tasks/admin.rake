# Admin management tasks
namespace :admin do
  desc "Grant admin access to user by email"
  task :grant, [:email] => :environment do |t, args|
    email = args[:email] || ENV['EMAIL']

    unless email
      puts "Usage: bin/rails admin:grant[email@example.com]"
      puts "   or: EMAIL=email@example.com bin/rails admin:grant"
      exit 1
    end

    user = User.find_by(email_address: email)

    unless user
      puts "❌ User not found: #{email}"
      exit 1
    end

    user.update!(admin: true)
    puts "✅ Admin access granted to: #{user.email_address}"
  end

  desc "Revoke admin access from user"
  task :revoke, [:email] => :environment do |t, args|
    email = args[:email] || ENV['EMAIL']

    user = User.find_by(email_address: email)

    if user
      user.update!(admin: false)
      puts "✅ Admin access revoked from: #{user.email_address}"
    else
      puts "❌ User not found: #{email}"
    end
  end

  desc "List all admin users"
  task :list => :environment do
    admins = User.where(admin: true)

    if admins.any?
      puts "👑 Admin users:"
      admins.each do |user|
        puts "  - #{user.email_address}"
      end
    else
      puts "No admin users found"
    end
  end
end
