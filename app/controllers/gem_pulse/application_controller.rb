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

      def gemfile_root
        # Use Bundler.root to find the directory containing Gemfile.lock.
        # In host apps this is typically Rails.root; in the dummy test app
        # Gemfile.lock lives at the engine root, not test/dummy/.
        Bundler.root
      end

      def load_gem_health
        inspector = GemInspector.new(app_root: gemfile_root)
        scanner = AdvisoryScanner.new(app_root: gemfile_root)
        client = RubygemsClient.new

        all_advisories = scanner.advisories

        inspector.gems.map do |gem_entry|
          rubygems_data = gem_entry.source == :rubygems ? client.info(gem_entry.name) : nil
          gem_advisories = all_advisories[gem_entry.name] || []

          score = HealthScore.new(
            gem_name: gem_entry.name,
            locked_version: gem_entry.locked_version,
            rubygems_data: rubygems_data,
            advisories: gem_advisories
          )

          {
            name: gem_entry.name,
            locked_version: gem_entry.locked_version,
            declared_version: gem_entry.declared_version,
            groups: gem_entry.groups,
            source: gem_entry.source,
            latest_version: rubygems_data&.dig(:latest_version),
            score: score.value,
            status: score.status,
            reasons: score.reasons,
            advisories: gem_advisories,
            rubygems_data: rubygems_data
          }
        end
      end
  end
end
