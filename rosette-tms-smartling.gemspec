$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'rosette/tms/smartling-tms/version'

Gem::Specification.new do |s|
  s.name     = "rosette-tms-smartling"
  s.version  = ::Rosette::Tms::SmartlingTms::VERSION
  s.authors  = ["Cameron Dutro"]
  s.email    = ["camertron@gmail.com"]
  s.homepage = "http://github.com/camertron"

  s.description = s.summary = "Smartling support for the Rosette internationalization platform."

  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true

  s.add_dependency 'nokogiri', '1.6.0'
  s.add_dependency 'smartling', '~> 0.5.0'
  s.add_dependency 'twitter_cldr', '~> 3.1.0'
  s.add_dependency 'concurrent-ruby', '~> 0.7.0'
  s.add_dependency 'tmx-parser', '~> 1.0.0'

  s.require_path = 'lib'
  s.files = Dir["{lib,spec}/**/*", "Gemfile", "History.txt", "README.md", "Rakefile", "rosette-tms-smartling.gemspec"]
end