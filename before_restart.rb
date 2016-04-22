#!/usr/bin/env ruby
puts "\e[0;33m--> Begin before_restart.rb\e[39m"

oldrev, newrev, branch = ARGV

def run(cmd)
  exit($?.exitstatus) unless system "umask 002 && #{cmd}"
end

RAILS_ENV   = case branch
    when /^staging$/ then 'staging'
    when /^master$/ then 'production'
    else ENV['RAILS_ENV']
  end

if ((branch =~ /^master$/) == nil) && ((branch =~ /^staging$/) == nil)
    exit
end

use_bundler = File.file? 'Gemfile'
rake_cmd    = use_bundler ? 'bundle exec rake' : 'rake'

if use_bundler
  bundler_args = ['--deployment']
  BUNDLE_WITHOUT = ENV['BUNDLE_WITHOUT'] || 'development:test'
  bundler_args << '--without' << BUNDLE_WITHOUT unless BUNDLE_WITHOUT.empty?

  # update gem bundle
  puts "\e[35m--> Running [ bundle install #{bundler_args.join(' ')} ]\e[39m"
  run "bundle install #{bundler_args.join(' ')}"
end

if File.file? 'Rakefile'
  tasks = []

  # num_migrations = `git diff #{oldrev} #{newrev} --diff-filter=A --name-only -z -- db/migrate`.split("\0").size
  # run migrations if new ones have been added
  num_migrations = 1
  tasks << "db:migrate" if num_migrations > 0

  # precompile assets
  # changed_assets = `git diff #{oldrev} #{newrev} --name-only -z -- app/assets`.split("\0")
  changed_assets = 1
  tasks << "assets:precompile" if changed_assets.size > 0

  puts "\e[35m--> Running [ #{rake_cmd} #{tasks.join(' ')} RAILS_ENV=#{RAILS_ENV} ]\e[39m" if tasks.any?
  run "#{rake_cmd} #{tasks.join(' ')} RAILS_ENV=#{RAILS_ENV}" if tasks.any?
end

# clear cached assets (unversioned/ignored files)
# run "git clean -x -f -- public/stylesheets public/javascripts"

# clean unversioned files from vendor/plugins (e.g. old submodules)
# run "git clean -d -f -- vendor/plugins"

puts "\e[33m--> End before_restart.rb\e[39m"
