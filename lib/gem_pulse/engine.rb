module GemPulse
  class Engine < ::Rails::Engine
    isolate_namespace GemPulse

    # Expose GemPulse configuration to the host app's initializer system.
    # Host apps configure the engine in config/initializers/gem_pulse.rb.
    config.gem_pulse = ActiveSupport::OrderedOptions.new

    initializer "gem_pulse.warn_if_unprotected" do
      if Rails.env.production? && GemPulse.configuration.before_action.nil?
        Rails.logger.warn(
          "[GemPulse] WARNING: GemPulse is mounted without access control. " \
          "Set GemPulse.configure { |c| c.before_action = -> { ... } } or " \
          "use route constraints to restrict access."
        )
      end
    end
  end
end
