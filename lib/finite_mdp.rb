require 'finite_mdp/version'
require 'finite_mdp/vector_valued'
require 'finite_mdp/solver'

module FiniteMDP
  #
  # A generic finite markov decision process model.
  #
  # Note that there is no special treatment for terminal states, but they can be
  # modeled by including a dummy state (a state with zero reward and one action
  # that brings the process back to the dummy state with probability 1).
  #
  module Model
    #
    # Array of states in this model.
    #
    # @return [Array]
    #
    def states
      raise NotImplementedError
    end

    #
    # Array of actions that are valid for 
    #
    # @param state
    #
    # @return [Array]
    #
    def actions state
      raise NotImplementedError
    end

    #
    # The transition model; a hash from next states to [probability, reward]
    # pairs that describes the results of taking the given action in the given
    # state.
    #
    # @param state
    #
    # @param action
    #
    # @return [Hash<Array>] 
    #
    def next_states state, action
      raise NotImplementedError
    end

    #
    # Reward for a given transition.
    #
    # @param state
    #
    # @param action
    #
    # @param next_state
    #
    # @return [Float, nil] reward nil if given transition is not allowed
    #
    def reward state, action, next_state
      raise NotImplementedError
    end
  end

  #
  # A finite markov decision process model for which the transition
  # probabilities and rewards are specified as a table. This is a common way of
  # specifying small models.
  #
  class TableModel
    include Model

    #
    # @param [Array<Array>] rows each row is [state, action, next state,
    # probability, reward]
    #
    def initialize rows
      @rows = rows
    end

    #
    # @return [Array<Array>]
    #
    attr_accessor :rows

    def states
      @rows.map{|row| row[0]}.uniq
    end

    def actions state
      @rows.map{|row| row[1] if row[0] == state}.compact.uniq
    end

    def next_states state, action
      @rows.map{|row| row[2] if row[0] == state && row[1] == action}.compact
    end 

    def transition_probability state, action, next_state
      @rows.map{|row| row[3] if row[0] == state &&
        row[1] == action && row[2] == next_state}.compact.first
    end

    def reward state, action, next_state
      @rows.map{|row| row[4] if row[0] == state &&
        row[1] == action && row[2] == next_state}.compact.first
    end

    #
    # Convert a generic model into a table model.
    #
    # @param [Model] not nil
    #
    # @return [TableModel] not nil
    #
    def self.from_model model
      rows = []
      model.states.each do |state|
        model.actions(state).each do |action|
          model.next_states(state, action).each do |next_state|
            rows << [state, action, next_state, 
              model.transition_probability(state, action, next_state),
              model.reward(state, action, next_state)]
          end
        end
      end
      TableModel.new(rows)
    end
  end

  #
  # A finite markov decision process model for which the transition
  # probabilities and rewards are specified using nested hash tables.
  #
  # The conventions for the nested hash are as follows: 
  #  hash[:s]         #=> a Hash that maps actions to successor states
  #  hash[:s][:a]     #=> a Hash from successor states to pairs (see next)
  #  hash[:s][:a][:t] #=> an Array [probability, reward] for transition (s,a,t)
  #
  # The states and actions can be arbitrary objects. Built-in types, such as
  # symbols and arrays, will work as expected. Note, however, that the default
  # hashing and equality semantics for custom classes may not be what you want;
  # see the notes for {VectorValued} for more information. 
  #
  class HashModel
    include Model

    def initialize hash
      @hash = hash
    end

    #
    # @return [Hash]
    #
    attr_accessor :hash

    def states
      hash.keys
    end

    def actions state
      hash[state].keys
    end

    def next_states state, action
      hash[state][action].keys
    end 

    def transition_probability state, action, next_state
      hash[state][action][next_state][0]
    end

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

#  #
#  # Array of arrays of hashes.
#  #
#  class NumericModel
#    def initialize numbers, model
#      @numbers = numbers
#      @model = model
#    end
#
#    attr_accessor :numbers
#
#    def states
#      (0...numbers.size).to_a
#    end
#
#    def actions state
#      (0...numbers[state].size).to_a
#    end
#
#    def next_states state, action
#      numbers[state][action].keys
#    end 
#
#    def transition_probability state, action, next_state
#      numbers[state][action][next_state][0]
#    end
#
#    def reward state, action, next_state
#      numbers[state][action][next_state][1]
#    end
#
#    def number_values values
#      states.map {|n| values[num_to_state[n]]}
#    end
#
#    def unnumber_values n_values
#      Hash[*states.map {|n| [num_to_state[n], n_values[n]]}]
#    end
#
#    def number_policy policy
#      # actions are numbered per state, so we get one map per state
#      #action_num = model.states.map{|state|
#      #  actions = model.actions(state)
#      #  Hash[*actions.zip(0...actions.size).flatten(1)]
#      #}
#
#      #states.map {|n| action_to_num[n][policy[num_to_state[n]]]}
#    end
#
#    def unnumber_policy n_policy
#      Hash[*states.map {|n|
#        state = num_to_state[n]
#        action = num_to_action[n][n_policy[n]]
#        [state, action]}.flatten(1)]
#    end
#
#    def self.from_model model
#      # build map from states to numbers
#      states = model.states
#      state_num = Hash[*states.zip(0...states.size).flatten(1)]
#
#      # store transition probabilities and rewards according to this numbering
#      data = states.map {|state|
#        model.actions(state).map {|action|
#          Hash[*model.next_states(state, action).map {|next_state|
#            [state_num[next_state], [
#              model.transition_probability(state, action, next_state),
#              model.reward(state, action, next_state)]]
#          }.flatten(1)]
#        }
#      }
#
#      NumericModel.new(data, model)
#    end
#  end
#
#  #
#  # Wrapper to convert a model with arbitrary state and action objects into one
#  # with numerical states; the states and actions are numbered arbitrarily.
#  #
#  class NumberedModel
#    include Model
#
#    def initialize model
#      @model = model
#
#      # build map from states to numbers
#      @state_num = Hash[*model.states.zip(0...model.states.size).flatten(1)]
#      @num_state = @state_num.invert
#
#      # build map from actions to numbers; it isn't strictly necessary to number
#      # all actions uniquely (could number within states -- not sure if there
#      # are any benefits to doing it that way instead)
#      all_actions = model.states.map{|state| model.actions(state)}.
#        flatten(1).uniq
#      @action_num = Hash[*all_actions.zip(0...all_actions.size).flatten(1)]
#      @num_action = @action_num.invert
#    end
#
#    def state_to_number state; @state_num[state] end
#    def action_to_number action; @action_num[action] end
#    def number_to_state n_state; @num_state[n_state] end
#    def number_to_action n_action; @num_action[n_action] end
#
#    def states
#      (0...model.states.size).to_a
#    end
#
#    def actions state
#      model.actions(number_to_state(state)).map{|action|
#        action_to_number(action)}
#    end
#
#    def next_states state, action
#      model.next_states(number_to_state(state), number_to_action(action)).
#        map{|next_state| state_to_number(next_state)}
#    end 
#
#    def transition_probability state, action, next_state
#      model.transition_probability(number_to_state(state),
#                                   number_to_action(action),
#                                   number_to_state(next_state))
#    end
#
#    def reward state, action, next_state
#      model.reward(number_to_state(state),
#                   number_to_action(action),
#                   number_to_state(next_state))
#    end
#  end

  # TODO maybe for efficiency it would be worth including a special case for
  # models in which rewards depend only on the state -- a few minor
  # simplifications are possible in the solver, but it won't make a huge
  # difference.
  #class HashModelWithStateRewards
  #  include Model
  #end
end
      #Hash[*@rows.map{|row|
      #  [row[2], row[3,2]] if row[0] == state && row[1] == action}.
      #    compact.flatten(1)]

