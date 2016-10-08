# -*- encoding: utf-8 -*-
# frozen_string_literal: true
require 'English'

lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'finite_mdp/version'

Gem::Specification.new do |s|
  s.name              = 'finite_mdp'
  s.version           = FiniteMDP::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = ['John Lees-Miller']
  s.email             = ['jdleesmiller@gmail.com']
  s.homepage          = 'http://github.com/jdleesmiller/finite_mdp'
  s.summary           = 'Solve small, finite Markov Decision Process models.'
  s.description       = 'This library provides several ways of describing a
finite Markov Decision Process (MDP) model (see FiniteMDP::Model) and some
reasonably efficient implementations of policy iteration and value iteration to
solve it (see FiniteMDP::Solver).'

  s.rubyforge_project = 'finite_mdp'

  s.add_runtime_dependency 'narray', '~> 0.6'
  s.add_development_dependency 'gemma', '> 2'

  s.files       = Dir.glob('{lib,bin}/**/*.rb') + %w(README.rdoc)
  s.test_files  = Dir.glob('test/finite_mdp/*_test.rb')
  s.executables = Dir.glob('bin/*').map { |f| File.basename(f) }

  s.rdoc_options = [
    '--main',    'README.rdoc',
    '--title',   "#{s.full_name} Documentation"
  ]
  s.extra_rdoc_files << 'README.rdoc'
end
