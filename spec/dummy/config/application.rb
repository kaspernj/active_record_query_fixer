require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "active_record_query_fixer"

module Dummy; end

class Dummy::Application < Rails::Application
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  if Gem.loaded_specs["rails"].version.to_s.start_with?("7.")
    config.load_defaults 7.0
  else
    config.load_defaults 6.0
  end
end
