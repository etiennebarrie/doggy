# encoding: utf-8

require "pathname"
require "net/http"
require "rugged"

require "doggy/cli"
require "doggy/cli/edit"
require "doggy/cli/mute"
require "doggy/cli/pull"
require "doggy/cli/push"
require "doggy/cli/unmute"
require "doggy/model"
require "doggy/models/dashboard"
require "doggy/models/monitor"
require "doggy/models/screen"
require "doggy/version"

module Doggy
  DOG_SKIP_REGEX         = /\xF0\x9F\x98\xB1|:scream:/i.freeze
  MANAGED_BY_DOGGY_REGEX = /\xF0\x9F\x90\xB6|:dog:/i.freeze

  extend self

  def ui
    (defined?(@ui) && @ui) || (self.ui = Thor::Shell::Color.new)
  end

  def ui=(ui)
    @ui = ui
  end

  def object_root
    @object_root ||= Pathname.new('objects').expand_path(repo_root)
  end

  def repo_root
    # TODO: Raise error when root can't be found
    current_dir = Dir.pwd

    while current_dir != '/' do
      if File.exists?(File.join(current_dir, 'Gemfile')) then
        return Pathname.new(current_dir)
      else
        current_dir = File.expand_path('../', current_dir)
      end
    end
  end

  def api_key
    ENV['DATADOG_API_KEY'] || secrets['datadog_api_key']
  end

  def application_key
    ENV['DATADOG_APP_KEY'] || secrets['datadog_app_key']
  end

  def modified(compare_to, all = false)
    @modified ||= begin
                    mods = Set.new
                    paths = repo.diff(compare_to, 'HEAD').each_delta.map { |delta| delta.new_file[:path] }
                    paths.each do |path|
                      parts = path.split('/')
                      next unless parts[0] =~ /objects/
                      next unless File.exist?(path)
                      mods << path
                    end
                    mods
                  end
  end

  def resolve_path(path)
    path     = Pathname.new(path)
    curr_dir = Pathname.new(Dir.pwd)
    resolved = object_root.relative_path_from(curr_dir)

    (curr_dir.expand_path(resolved + path) + path).to_s
  end


  protected

  def secrets
    @secrets ||= begin
                   raw = File.read(repo_root.join('secrets.json'))
                   JSON.parse(raw)
                 end
  end

  def repo
    @repo ||= Rugged::Repository.new(Doggy.object_root.parent.to_s)
  end
end # Doggy
