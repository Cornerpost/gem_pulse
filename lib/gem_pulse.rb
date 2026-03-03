require "gem_pulse/version"
require "gem_pulse/engine"

module GemPulse
  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end

  class Configuration
    # Lambda or proc run as a before_action in GemPulse::ApplicationController.
    # Use this to enforce authentication from the host app.
    #
    # Example:
    #   GemPulse.configure do |config|
    #     config.before_action = -> { redirect_to root_path unless current_user&.admin? }
    #   end
    attr_accessor :before_action

    # Title displayed in the GemPulse dashboard header.
    attr_accessor :title

    # How long to cache RubyGems.org API responses, in seconds.
    # Reduces API calls when multiple users view the dashboard in quick succession.
    attr_accessor :cache_ttl

    def initialize
      @before_action = nil
      @title         = "Gem Health"
      @cache_ttl     = 3600 # 1 hour
    end
  end
end
