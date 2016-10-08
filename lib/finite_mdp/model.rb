# frozen_string_literal: true
#
# Interface that defines a finite markov decision process model.
#
# There are several approaches to describing the state, action, transition
# probability and reward data for use with this library.
#
# 1. Write the data directly into a {TableModel} or {HashModel}. This is usually
#    the way to go for small models, such as examples from text books.
#
# 1. Write a procedure that generates the data and stores them in a
#    {TableModel} or {HashModel}. This gives the most flexibility in how the
#    data are generated.
#
# 1. Write a class that implements the methods in this module. The methods in
#    this module are a fairly close approximation to the usual way of defining
#    an MDP mathematically, so it can be a useful way of structuring the
#    definition. It can then be converted to one of the other representations
#    (see {TableModel.from_model}) or passed directly to a {Solver}.
#
# The discussion below applies to all of these approaches.
#
# Note that there is no special treatment for terminal states, but they can be
# modeled by including a dummy state (a state with zero reward and one action
# that brings the process back to the dummy state with probability 1).
#
# The states and actions can be arbitrary objects. The only requirement is that
# they support hashing and equality (in the sense of <tt>eql?</tt>), which all
# ruby objects do. Built-in types, such as symbols, arrays and Structs, will
# work as expected. Note, however, that the default hashing and equality
# semantics for custom classes may not be what you want. The following example
# illustrates this:
#
#   class BadGridState
#     def initialize x, y
#       @x, @y = x, y
#     end
#     attr_accessor :x, :y
#   end
#
#   BadGridState.new(1, 1) == BadGridState.new(1, 2) #=> false
#   BadGridState.new(1, 1) == BadGridState.new(1, 1) #=> false (!!!)
#
# This is because, by default, hashing and equality are defined in terms of
# object identifiers, not the 'content' of the objects.
# The preferred solution is to define the state as a <tt>Struct</tt>:
#
#   GoodGridState = Struct.new(:x, :y)
#
#   GoodGridState.new(1, 1) == GoodGridState.new(1, 2) #=> false
#   GoodGridState.new(1, 1) == GoodGridState.new(1, 1) #=> true
#
# <tt>Struct</tt> is part of the ruby standard library, and it implements
# hashing and equality based on object content rather than identity.
#
# Alternatively, if you cannot derive your state class from <tt>Struct</tt>, you
# can define your own hash code and equality check. An easy way to do this is to
# include the {VectorValued} mix-in. It is also notable that you can make the
# default semantics work; you just have to make sure that there is only one
# instance of your state class per state, as in the following example:
#
#   g11 = BadGridState.new(1, 1)
#   g12 = BadGridState.new(1, 2)
#   g21 = BadGridState.new(2, 1)
#   model = FiniteMDP::TableModel.new([
#     [g11, :up,    g12, 0, 0.9],
#     [g11, :up,    g21, 0, 0.1],
#     [g11, :right, g21, 0, 0.9],
#     # ...
#     ]) # this will work as expected
#
# Note that the {Solver} will convert the model to its own internal
# representation. The efficiency of the methods that define the model is
# important while the solver is building its internal representation, but it
# does not affect the performance of the iterative algorithm used after that.
# Also note that the solver handles state and action numbering internally, so it
# is not necessary to use numbers for the states.
#
module FiniteMDP::Model
  #
  # States in this model.
  #
  # @return [Array<state>] not empty; no duplicate states
  #
  # @abstract
  #
  def states
    raise NotImplementedError
  end

  #
  # Actions that are valid for the given state.
  #
  # All states must have at least one valid action; see notes for {Model}
  # regarding how to encode a terminal state.
  #
  # @param [state] state
  #
  # @return [Array<action>] not empty; no duplicate actions
  #
  # @abstract
  #
  def actions(_state)
    raise NotImplementedError
  end

  #
  # Successor states after taking the given action in the given state. Note that
  # the returned states may occur with zero probability.
  #
  # The default behavior is to return all states as candidate successor states
  # and let {#transition_probability} determine which ones are possible. It can
  # be overridden in sparse models to avoid storing or computing lots of zeros.
  # Also note that {TableModel.from_model} and {HashModel.from_model} can be
  # told to ignore transitions with zero probability, and that the {Solver}
  # ignores them in its internal representation, so you can usually forget about
  # this method.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @return [Array<state>] not empty; no duplicate states
  #
  def next_states(_state, _action)
    states
  end

  #
  # Probability of the given transition.
  #
  # If the transition is not in the model, in the sense that it would never
  # arise from {#states}, {#actions} and {#next_states}, the result is
  # undefined. Note that {HashModel#transition_probability} and
  # {TableModel#transition_probability} return zero in this case, but this is
  # not part of the contract.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @param [state] next_state
  #
  # @return [Float] in [0, 1]; undefined if the transition is not in the model
  #  (see notes above)
  #
  # @abstract
  #
  def transition_probability(_state, _action, _next_state)
    raise NotImplementedError
  end

  #
  # Reward for a given transition.
  #
  # If the transition is not in the model, in the sense that it would never
  # arise from {#states}, {#actions} and {#next_states}, the result is
  # undefined. Note that {HashModel#reward} and {TableModel#reward} return
  # <tt>nil</tt> in this case, but this is not part of the contract.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @param [state] next_state
  #
  # @return [Float, nil] nil only if the transition is not in the model (but the
  #  result is undefined in this case -- it need not be nil; see notes above)
  #
  # @abstract
  #
  def reward(_state, _action, _next_state)
    raise NotImplementedError
  end

  #
  # Sum of the transition probabilities for each (state, action) pair; the sums
  # should be one in a valid model.
  #
  # @return [Hash<[State, Action], Float>]
  #
  def transition_probability_sums
    prs = []
    states.each do |state|
      actions(state).each do |action|
        pr = next_states(state, action).map do |next_state|
          transition_probability(state, action, next_state)
        end.inject(:+)
        prs << [[state, action], pr]
      end
    end
    Hash[prs]
  end

  #
  # Raise an error if the sum of the transition probabilities for any (state,
  # action) pair is not sufficiently close to 1.
  #
  # @param [Float] tol numerical tolerance
  #
  # @return [nil]
  #
  def check_transition_probabilities_sum(tol = 1e-6)
    transition_probability_sums.each do |(state, action), pr|
      raise "transition probabilities for state #{state.inspect} and
          action #{action.inspect} sum to #{pr}" if pr < 1 - tol
    end
    nil
  end

  #
  # Set of states that have no transitions out.
  #
  # At present, this library can't solve a model with terminal states. However,
  # you can add a dummy state (e.g. <tt>:stop</tt>) with zero reward that
  # transitions back to itself with probability one.
  #
  # Note that if a state has transitions out, but all of them have probability
  # zero, this method does not detect it as a terminal state. You can check for
  # these using {#transition_probability_sums} instead.
  #
  # @return [Set]
  #
  def terminal_states
    all_states = Set[]
    out_states = Set[]
    states.each do |state|
      all_states << state
      any_out_transitions = false
      actions(state).each do |action|
        ns = next_states(state, action)
        all_states.merge ns
        any_out_transitions ||= !ns.empty?
      end
      out_states << state if any_out_transitions
    end
    all_states - out_states
  end
end
