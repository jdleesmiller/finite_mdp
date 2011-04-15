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
  def actions state
    raise NotImplementedError
  end

  #
  # Possible successor states after taking the given action in the given state.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @return [Array<state>] not empty; no duplicate states
  #
  # @abstract
  #
  def next_states state, action
    raise NotImplementedError
  end

  #
  # Probability of the given transition.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @param [state] next_state
  #
  # @return [Float] in [0, 1]; result is undefined if the transition is not
  #  allowed
  #
  # @abstract
  #
  def transition_probability state, action, next_state
    raise NotImplementedError
  end

  #
  # Reward for a given transition.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @param [state] next_state
  #
  # @return [Float] result is undefined if the transition is not allowed
  #
  # @abstract
  #
  def reward state, action, next_state
    raise NotImplementedError
  end
end

