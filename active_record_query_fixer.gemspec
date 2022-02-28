$LOAD_PATH.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "active_record_query_fixer/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name = "active_record_query_fixer"
  s.version = ActiveRecordQueryFixer::VERSION
  s.authors = ["kaspernj"]
  s.email = ["k@spernj.org"]
  s.homepage = "https://www.github.com/kaspernj/active_record_query_fixer"
  s.summary = "A library for automatically added `.select` on a column used for `.distinct` or automatically adding `.group` for a column used for order."
  s.description = "A library for automatically added `.select` on a column used for `.distinct` or automatically adding `.group` for a column used for order."
  s.license = "MIT"
  s.metadata["rubygems_mfa_required"] = "true"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "dig_bang"
  s.add_development_dependency "appraisal"
  s.add_development_dependency "rails", ">= 6.0.0"
end
