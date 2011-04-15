#
# Use policy iteration and value iteration (and a few variants thereon) to solve
# MDPs with state and action spaces that are finite and sufficiently small to be
# explicitly represented in memory.
#
class FiniteMDP::Solver
  def initialize model, discount, policy, value=Hash.new(0)
    @model = model

    # get the model data into a more compact form for calculation; this means
    # that we number the states and actions for faster lookups (avoid most of
    # the hashing); the 'next states' map is still stored in sparse format
    # (that is, as a hash)
    model_states = model.states
    @state_to_num = Hash[*model_states.enum_with_index.to_a.flatten(1)]
    @compacted_model = model_states.map {|state|
      model.actions(state).map {|action|
        Hash[*model.next_states(state, action).map {|next_state|
          [@state_to_num[next_state], [
            model.transition_probability(state, action, next_state),
            model.reward(state, action, next_state)]]
        }.flatten(1)]
      }
    }

    # also must convert the initial policy and initial value into compact form;
    # to do this, we build a map from actions to action numbers; actions are
    # numbered per state, so we get one map per state
    @action_to_num = model_states.map{|state|
      actions = model.actions(state)
      Hash[*actions.enum_with_index.to_a.flatten(1)]
    }

    @discount = discount
    @compacted_value  = model_states.map {|state| value[state]}
    @compacted_policy = @action_to_num.zip(model_states).
                          map {|a_to_n, state| a_to_n[policy[state]]}
  end

  attr_accessor :model

  # 
  # State values
  #
  # NB: this is read only
  #
  # @return [Hash<state, Float>] from states to values
  #
  def value
    Hash[*model.states.zip(@compacted_value).flatten(1)]
  end

  #
  # Policy
  #
  # NB: this is read only
  #
  # @return [Hash<state, action>]
  #
  def policy
    Hash[*model.states.zip(@compacted_policy).map{|state, action_n|
      [state, model.actions(state)[action_n]]}.flatten(1)]
  end

  #
  # Refine our estimate of the value function for the current policy; this can
  # be used to implement variants of policy iteration.
  #
  # This is the 'policy evaluation' step in Figure 4.3 of Sutton and Barto
  # (1998).
  #
  # @return [Float] largest absolute change (over all states) in the value
  # function
  #
  def evaluate_policy
    delta = 0.0
    @compacted_model.each_with_index do |actions, state_n|
      next_state_ns = actions[@compacted_policy[state_n]]
      new_value = backup(next_state_ns)
      delta = [delta, (@compacted_value[state_n] - new_value).abs].max
      @compacted_value[state_n] = new_value
    end
    delta
  end

  #
  # Make our policy greedy with respect to our current value function; this can
  # be used to implement variants of policy iteration.
  #
  # This is the 'policy improvement' step in Figure 4.3 of Sutton and Barto
  # (1998).
  # 
  # @return [Boolean] false iff the policy changed for any state
  #
  def improve_policy
    stable = true
    @compacted_model.each_with_index do |actions, state_n|
      a_max = nil
      v_max = -Float::MAX
      actions.each_with_index do |next_state_ns, action_n|
        v = backup(next_state_ns)
        if v > v_max
          a_max = action_n
          v_max = v
        end
      end
      raise "no feasible actions in state #{state_n}" unless a_max
      stable = false if @compacted_policy[state_n] != a_max
      @compacted_policy[state_n] = a_max
    end
    stable
  end

  #
  # Do one iteration of value iteration.
  #
  # This is the algorithm from Figure 4.5 of Sutton and Barto (1998). It is
  # mostly equivalent to calling evaluate_policy and then improve_policy, but it
  # does fewer backups.
  #
  # @return [Float] largest absolute change (over all states) in the value
  # function
  #
  def one_value_iteration
    delta = 0.0
    @compacted_model.each_with_index do |actions, state_n|
      a_max = nil
      v_max = -Float::MAX
      actions.each_with_index do |next_state_ns, action_n|
        v = backup(next_state_ns)
        if v > v_max
          a_max = action_n
          v_max = v
        end
      end
      delta = [delta, (@compacted_value[state_n] - v_max).abs].max
      @compacted_value[state_n] = v_max
      @compacted_policy[state_n] = a_max
    end
    delta
  end

  private

  def backup next_state_ns
    next_state_ns.map {|next_state_n, (probability, reward)|
      probability*(reward + @discount*@compacted_value[next_state_n])
    }.inject(:+)
  end
end

#class FiniteMDP::Solver
#  def initialize transitions, reward, discount, policy,
#    value=Hash.new {|v,s| v[s] = reward[s]}
#    
#    @transitions = transitions
#    @reward      = reward
#    @discount    = discount
#    @value       = value
#    @policy      = policy
#  end
#
#  attr_accessor :value, :policy
#
#  #
#  # Refine our estimate of the value function for the current policy; this can
#  # be used to implement variants of policy iteration.
#  #
#  # This is the 'policy evaluation' step in Figure 4.3 of Sutton and Barto
#  # (1998).
#  #
#  # @return [Float] largest absolute change (over all states) in the value
#  # function
#  #
#  def evaluate_policy
#    delta = 0.0
#    for state, actions in @transitions
#      new_value = @reward[state]
#      for succ, succ_pr in actions[@policy[state]]
#        new_value += @discount*succ_pr*@value[succ]
#      end
#      delta = [delta, (@value[state] - new_value).abs].max
#      @value[state] = new_value
#    end
#    delta
#  end
#
#  #
#  # Make our policy greedy with respect to our current value function; this can
#  # be used to implement variants of policy iteration.
#  #
#  # This is the 'policy improvement' step in Figure 4.3 of Sutton and Barto
#  # (1998).
#  # 
#  # @return [Boolean] false iff the policy changed for any state
#  #
#  def improve_policy
#    stable = true
#    for state, actions in @transitions
#      a_max = nil
#      v_max = -Float::MAX
#      for action in actions.keys
#        v = succs.map{|succ, pr| @discount*pr*@value[succ]}.inject(:+)
#        if v > v_max
#          a_max = action
#          v_max = v
#        end
#      end
#      raise "no feasible actions in state #{state}" unless a_max
#      stable = false if @policy[state] != a_max
#      @policy[state] = a_max
#    end
#    stable
#  end
#
#  #
#  # Do one iteration of value iteration.
#  #
#  # This is the algorithm from Figure 4.5 of Sutton and Barto (1998). It is
#  # mostly equivalent to calling evaluate_policy and then improve_policy, but it
#  # does fewer backups.
#  #
#  # @return [Float] largest absolute change (over all states) in the value
#  # function
#  #
#  def value_iteration
#    delta = 0.0
#    for state, actions in @transitions
#      for action, succs in actions
#        v = succs.map{|succ, pr| @discount*pr*@value[succ]}.inject(:+)
#        if v > v_max
#          a_max = action
#          v_max = v
#        end
#      end
#      v_max += @reward[state]
#      delta = [delta, (@value[state] - v_max).abs].max
#      @value[state]  = v_max
#      @policy[state] = a_max
#    end
#    delta
#  end
#end

