# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "passify/version"

Gem::Specification.new do |s|
  s.name        = "passify"
  s.version     = Passify::VERSION
  s.authors     = ["Fabian Schwahn"]
  s.email       = ["fabian.schwahn@gmail.com"]
  s.homepage    = "https://github.com/fschwahn/passify"
  s.summary     = %q{PassengerPane-compatible CLI for Phusion Passenger}
  s.description = %q{passify is a command line interface (CLI) for Phusion Passenger, equivalent to what powder and powify are for pow. passify is compatible with PassengerPane.}

  s.rubyforge_project = "passify"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_runtime_dependency "thor"
  s.add_development_dependency "rake"
end
