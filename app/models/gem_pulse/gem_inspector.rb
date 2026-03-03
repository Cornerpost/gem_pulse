module GemPulse
  class GemInspector
    GemEntry = Struct.new(:name, :locked_version, :declared_version, :groups, :source, keyword_init: true)

    attr_reader :app_root

    def initialize(app_root: Rails.root)
      @app_root = Pathname.new(app_root)
    end

    def gems
      @gems ||= build_gem_list
    end

    private

    def build_gem_list
      lockfile_specs.map do |spec|
        source = source_type(spec)
        declared = declarations[spec.name]

        GemEntry.new(
          name: spec.name,
          locked_version: spec.version.to_s,
          declared_version: declared&.fetch(:requirement, ">= 0"),
          groups: declared&.fetch(:groups, [:default]) || [:default],
          source: source
        )
      end
    end

    def lockfile_specs
      @lockfile_specs ||= begin
        content = lockfile_path.read
        parser = Bundler::LockfileParser.new(content)
        parser.specs
      end
    end

    def source_type(spec)
      case spec.source
      when Bundler::Source::Git
        :git
      when Bundler::Source::Path
        :path
      else
        :rubygems
      end
    end

    def declarations
      @declarations ||= parse_gemfile
    end

    def parse_gemfile
      return {} unless gemfile_path.exist?

      dsl = Bundler::Dsl.new
      dsl.eval_gemfile(gemfile_path)
      definition = dsl.to_definition(lockfile_path, {})

      result = {}
      definition.dependencies.each do |dep|
        result[dep.name] = {
          requirement: dep.requirement.to_s,
          groups: dep.groups
        }
      end
      result
    rescue Bundler::GemfileError, Bundler::GemfileEvalError
      {}
    end

    def gemfile_path
      app_root.join("Gemfile")
    end

    def lockfile_path
      app_root.join("Gemfile.lock")
    end
  end
end
