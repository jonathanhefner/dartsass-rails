# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "fileutils"
require "rails"
require "rails/test_help"

module RailsAppHelpers
  def self.included(base)
    base.include ActiveSupport::Testing::Isolation
  end

  private
    def sprockets?
      Gem.loaded_specs.key?("sprockets-rails")
    end

    def propshaft?
      Gem.loaded_specs.key?("propshaft")
    end

    def asset_pipeline_option
      if Rails::VERSION::MAJOR > 7
        if propshaft?
          "--asset-pipeline=propshaft"
        elsif sprockets?
          "--asset-pipeline=sprockets"
        end
      end
    end

    def create_new_rails_app(app_dir)
      require "rails/generators/rails/app/app_generator"
      Rails::Generators::AppGenerator.start([app_dir, *asset_pipeline_option, "--skip-bundle", "--skip-bootsnap", "--quiet"])

      Dir.chdir(app_dir) do
        gemfile = File.read("Gemfile")

        gemfile.gsub!(/^gem ["']sassc?-rails["'].*/, "") # for Rails 6.1 and 7.0
        gemfile.gsub!(/^gem ["']dartsass-rails["'].*/, "")
        gemfile << %(gem "dartsass-rails", path: #{File.expand_path("..", __dir__).inspect}\n)

        if Rails::VERSION::PRE == "alpha"
          gemfile.gsub!(/^gem ["']rails["'].*/, "")
          gemfile << %(gem "rails", path: #{Gem.loaded_specs["rails"].full_gem_path.inspect}\n)
        end

        File.write("Gemfile", gemfile)

        # puts "?" * 50
        # system("gem install rails --version 7.0.8")
        # Dir.chdir("/tmp") { system("rails _7.0.8_ new wtf") }
        # puts "?" * 50
        puts "~" * 50
        # system("gem pristine sass-embedded --version 1.69.5")
        Bundler.with_unbundled_env { system("gem", "install", "sass-embedded") }
        puts "~" * 50
        run_command("bundle", "install")
        system("cat", "/opt/hostedtoolcache/Ruby/3.0.6/x64/lib/ruby/gems/3.0.0/extensions/x86_64-linux/3.0.0/sass-embedded-1.69.5/gem_make.out")
      end
    end

    def with_new_rails_app(&block)
      require "digest/sha1"
      variant = [Gem.loaded_specs["rails"].full_gem_path, asset_pipeline_option]
      app_name = "app_#{Digest::SHA1.hexdigest(variant.to_s)}"
      cache_dir = "#{__dir__}/../tmp"

      Dir.mktmpdir do |tmpdir|
        if Dir.exist?("#{cache_dir}/#{app_name}")
          FileUtils.cp_r("#{cache_dir}/#{app_name}", tmpdir)
        else
          create_new_rails_app("#{tmpdir}/#{app_name}")
          FileUtils.cp_r("#{tmpdir}/#{app_name}", cache_dir) # Cache app for future runs.
        end

        Dir.chdir("#{tmpdir}/#{app_name}", &block)
      end
    end

    def run_command(*command)
      Bundler.with_unbundled_env do
        puts "-" * 50
        pp command
        # capture_subprocess_io { system(*command, exception: true) }
        x = capture_subprocess_io { system(*command) }
        pp x
        puts "-" * 50
        x
      end
    end
end
