require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "active_record_query_fixer"

module Dummy; end

class Dummy::Application < Rails::Application
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
end
