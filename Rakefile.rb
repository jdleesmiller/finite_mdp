begin
  require 'rubygems'
  require 'gemma'

  Gemma::RakeTasks.with_gemspec_file 'finite_mdp.gemspec'
rescue LoadError
  puts 'Install gemma (sudo gem install gemma) for more rake tasks.'
end

task :default => :test
