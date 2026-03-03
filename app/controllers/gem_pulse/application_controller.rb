module GemPulse
  class ApplicationController < ActionController::Base
    # Run the host app's authentication hook if configured.
    #
    # In the host app's config/initializers/gem_pulse.rb:
    #   GemPulse.configure do |config|
    #     config.before_action = -> { redirect_to root_path unless current_user&.admin? }
    #   end
    before_action :run_gem_pulse_before_action

    # Make configuration available to all GemPulse views.
    helper_method :gem_pulse_config

    private

      def run_gem_pulse_before_action
        hook = GemPulse.configuration.before_action
        instance_exec(&hook) if hook
      end

      def gem_pulse_config
        GemPulse.configuration
      end
  end
end
