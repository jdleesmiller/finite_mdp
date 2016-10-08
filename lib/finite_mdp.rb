# frozen_string_literal: true
require 'enumerator'

require 'finite_mdp/version'
require 'finite_mdp/vector_valued'
require 'finite_mdp/model'
require 'finite_mdp/array_model'
require 'finite_mdp/hash_model'
require 'finite_mdp/table_model'
require 'finite_mdp/solver'

# TODO: maybe for efficiency it would be worth including a special case for
# models in which rewards depend only on the state -- a few minor
# simplifications are possible in the solver, but it won't make a huge
# difference.
