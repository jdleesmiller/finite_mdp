#
# A finite markov decision process model for which the transition
# probabilities and rewards are specified using nested hash tables.
#
# The structure of the nested hash is as follows:
#  hash[:s]         #=> a Hash that maps actions to successor states
#  hash[:s][:a]     #=> a Hash from successor states to pairs (see next)
#  hash[:s][:a][:t] #=> an Array [probability, reward] for transition (s,a,t)
#
# The states and actions can be arbitrary objects; see notes for {Model}.
#
# The {TableModel} is an alternative way of storing these data.
#
class FiniteMDP::HashModel
  include Model

  #
  # @param [Hash<state, Hash<action, Hash<state, [Float, Float]>>>] see notes
  # for {HashModel} for an explanation of this structure
  #
  def initialize hash
    @hash = hash
  end

  #
  # @return [Hash<state, Hash<action, Hash<state, [Float, Float]>>>] see notes
  # for {HashModel} for an explanation of this structure
  #
  attr_accessor :hash

  #
  # States in this model; see {Model#states}.
  #
  # @return [Array<state>] not empty; no duplicate states
  #
  def states
    hash.keys
  end

  #
  # Actions that are valid for the given state; see {Model#actions}.
  #
  # @param [state] state
  #
  # @return [Array<action>] not empty; no duplicate actions
  #
  def actions state
    hash[state].keys
  end

  #
  # Possible successor states after taking the given action in the given state;
  # see {Model#next_states}.
  # 
  # @param [state] state
  #
  # @param [action] action
  #
  # @return [Array<state>] not empty; no duplicate states
  #
  def next_states state, action
    hash[state][action].keys
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
  # @return [Float] in [0, 1]
  #
  def transition_probability state, action, next_state
    hash[state][action][next_state][0]
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
  # @return [Float] result is undefined if the transition is not allowed
  #
  def reward state, action, next_state
    hash[state][action][next_state][1]
  end

  #
  # Convert a generic model into a hash model.
  #
  # @param [Model] not nil
  #
  # @return [HashModel] not nil
  #
  def self.from_model model
    hash = {}
    model.states.each do |state|
      hash[state] ||= {}
      model.actions(state).each do |action|
        hash[state][action] ||= {}
        model.next_states(state, action).each do |next_state|
          hash[state][action][next_state] = [
            model.transition_probability(state, action, next_state),
            model.reward(state, action, next_state)]
        end
      end
    end
    HashModel.new(hash)
  end
end

