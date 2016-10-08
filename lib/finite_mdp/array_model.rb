# frozen_string_literal: true
#
# A finite markov decision process model for which the states, transition
# probabilities and rewards are stored in a sparse nested array format:
#   model[state_num][action_num] = [[next_state_num, probability, reward], ...]
#
# Note: The action_num is not consistent between states --- each state's action
# array contains only the actions that apply in that state.
#
# This class also maintains a {StateActionMap} to map between the state and
# action numbers and the original states and actions.
#
class FiniteMDP::ArrayModel
  include FiniteMDP::Model

  #
  # Map between states and actions and their corresponding indexes. This is used
  # with an {ArrayModel}, which works only with the indexes internally.
  #
  class StateActionMap
    def initialize
      @map = []
    end

    attr_reader :map

    def add(state, actions)
      @map << [state, actions]
    end

    def states
      @map.map { |state, _actions| state }
    end

    def actions(state)
      _state, actions = @map[state_index(state)]
      actions
    end

    def state_action_index(state, action)
      index = state_index(state)
      [index, @map[index][1].index(action)]
    end

    def state(index)
      @map[index][0]
    end

    def state_index(state)
      @map.index { |test_state, _actions| test_state == state }
    end

    #
    # Build from a model.
    #
    # @param [Model] model
    #
    # @param [Boolean] ordered assume states are orderable; default is to
    #        inspect the first state
    #
    def self.from_model(model, ordered = nil)
      model_states = model.states

      ordered = model_states.first.respond_to?(:>=) if ordered.nil?
      map = ordered ? OrderedStateActionMap.new : StateActionMap.new
      model_states.each do |state|
        map.add(state, model.actions(state))
      end
      map
    end
  end

  #
  # A {StateActionMap} for states that support ordering. Lookups are more
  # efficient than for an ordinary {StateActionMap}, which does not assume that
  # states can be ordered.
  #
  class OrderedStateActionMap < StateActionMap
    def add(state, actions)
      index = state_index(state)
      @map.insert(index || @map.size, [state, actions])
    end

    def state_index(state)
      (0...@map.size).bsearch { |i| @map[i][0] >= state }
    end
  end

  #
  # @param [Array<Array<Array>>] array see notes for {ArrayModel}
  # @param [StateActionMap] state_action_map
  #
  def initialize(array, state_action_map)
    @array = array
    @state_action_map = state_action_map
  end

  #
  # @return [Array<Array<Array>>>] array see notes for {ArrayModel}
  #
  attr_reader :array

  #
  # @return [StateActionMap]
  #
  attr_reader :state_action_map

  #
  # States in this model; see {Model#states}.
  #
  # @return [Array<state>] not empty; no duplicate states
  #
  def states
    @state_action_map.states
  end

  #
  # Number of states in the model.
  #
  # @return [Fixnum] positive
  #
  def num_states
    @state_action_map.map.size
  end

  #
  # Actions that are valid for the given state; see {Model#actions}.
  #
  # @param [state] state
  #
  # @return [Array<state>] not empty; no duplicate actions
  #
  def actions(state)
    @state_action_map.actions(state)
  end

  #
  # Possible successor states after taking the given action in the given state;
  # see {Model#next_states}.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @return [Array<state>] not empty; no duplicates
  #
  def next_states(state, action)
    state_index, action_index =
      @state_action_map.state_action_index(state, action)
    @array[state_index][action_index].map do |next_state_index, _pr, _reward|
      @state_action_map.state(next_state_index)
    end
  end

  #
  # Probability of the given transition; see {Model#transition_probability}.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @param [state] next_state
  #
  # @return [Float] in [0, 1]; zero if the transition is not in the model
  #
  def transition_probability(state, action, next_state)
    state_index, action_index =
      @state_action_map.state_action_index(state, action)
    next_state_index = @state_action_map.state_index(next_state)
    @array[state_index][action_index].each do |index, probability, _reward|
      return probability if index == next_state_index
    end
    0
  end

  #
  # Reward for a given transition; see {Model#reward}.
  #
  # @param [state] state
  #
  # @param [action] action
  #
  # @param [state] next_state
  #
  # @return [Float, nil] nil if the transition is not in the model
  #
  def reward(state, action, next_state)
    state_index, action_index =
      @state_action_map.state_action_index(state, action)
    next_state_index = @state_action_map.state_index(next_state)
    @array[state_index][action_index].each do |index, _probability, reward|
      return reward if index == next_state_index
    end
    nil
  end

  #
  # Convert a generic model into a hash model.
  #
  # @param [Model] model
  #
  # @param [Boolean] sparse do not store entries for transitions with zero
  #        probability
  #
  # @param [Boolean] ordered assume states are orderable; default is to inspect
  #        the first state
  #
  # @return [ArrayModel]
  #
  def self.from_model(model, sparse = true, ordered = nil)
    state_action_map = StateActionMap.from_model(model, ordered)

    array = state_action_map.states.map do |state|
      state_action_map.actions(state).map do |action|
        model.next_states(state, action).map do |next_state|
          pr = model.transition_probability(state, action, next_state)
          next unless pr > 0 || !sparse
          reward = model.reward(state, action, next_state)
          [state_action_map.state_index(next_state), pr, reward]
        end.compact
      end
    end

    FiniteMDP::ArrayModel.new(array, state_action_map)
  end
end
