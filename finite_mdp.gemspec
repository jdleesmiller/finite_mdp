# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'finite_mdp/version'
 
Gem::Specification.new do |s|
  s.name              = 'finite_mdp'
  s.version           = FiniteMDP::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = ['John Lees-Miller']
  s.email             = ['jdleesmiller@gmail.com']
  s.homepage          = 'http://github.com/jdleesmiller/finite_mdp'
  s.summary           = %q{Solve small, finite Markov Decision Process models.}
  s.description       = %q{This library provides several ways of describing a
finite Markov Decision Process (MDP) model (see FiniteMDP::Model) and some
reasonably efficient implementations of policy iteration and value iteration to
solve it (see FiniteMDP::Solver).}

  s.rubyforge_project = 'finite_mdp'

  s.add_runtime_dependency 'narray', '~> 0.5.9'
  s.add_development_dependency 'gemma', '~> 1.0.1'

  s.files       = Dir.glob('{lib,bin}/**/*.rb') + %w(README.rdoc)
  s.test_files  = Dir.glob('test/*_test.rb')
  s.executables = Dir.glob('bin/*').map{|f| File.basename(f)}

  s.rdoc_options = [
    "--main",    "README.rdoc",
    "--title",   "#{s.full_name} Documentation"]
  s.extra_rdoc_files << "README.rdoc"
end

