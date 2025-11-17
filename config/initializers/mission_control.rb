# Mission Control Jobs - Production Access
# Hardcoded credentials for Basic Auth

Rails.application.configure do
  config.mission_control.jobs.http_basic_auth_user = "admin"
  config.mission_control.jobs.http_basic_auth_password = "TrackerDelivery2025!"
end
