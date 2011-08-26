# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "passify/version"

Gem::Specification.new do |s|
  s.name        = "passify"
  s.version     = Passify::VERSION
  s.authors     = ["Fabian Schwahn"]
  s.email       = ["fabian.schwahn@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Write a gem summary}
  s.description = %q{Write a gem description}

  s.rubyforge_project = "passify"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_runtime_dependency "thor"
  s.add_development_dependency "rake"
end
