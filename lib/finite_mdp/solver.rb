# frozen_string_literal: true

# We use A to denote a matrix, which rubocop does not like.
# rubocop:disable Style/MethodName
# rubocop:disable Style/VariableName

require 'narray'

#
# Find optimal values and policies using policy iteration and/or value
# iteration. The methods here are suitable for finding deterministic policies
# for infinite-horizon problems.
#
# The computations are carried out on an intermediate form of the given model,
# which is stored using nested arrays:
#   model[state_num][action_num] = [[next_state_num, probability, reward], ...]
# The solver assigns numbers to each state and each action automatically. Note
# that the successor state data are stored in sparse format, and any transitions
# that are in the given model but have zero probability are not stored.
#
# TODO implement backward induction for finite horizon problems
#
# TODO maybe implement a 'dense' storage format for models with many successor
# states, probably as a different solver class
#
class FiniteMDP::Solver
  #
  # @param [Model] model
  #
  # @param [Float] discount in (0, 1]
  #
  # @param [Hash<state, action>, nil] policy initial policy; if nil, an
  #        arbitrary action is selected for each state
  #
  # @param [Hash<state, Float>] value initial value for each state; defaults to
  #        zero for every state
  #
  def initialize(model, discount, policy = nil, value = Hash.new(0))
    @discount = discount

    # get the model data into a more compact form for calculation; this means
    # that we number the states and actions for faster lookups (avoid most of
    # the hashing)
    @model =
      if model.is_a?(FiniteMDP::ArrayModel)
        model
      else
        FiniteMDP::ArrayModel.from_model(model)
      end

    # convert initial values and policies to compact form
    @array_value = @model.states.map { |state| value[state] }
    @array_policy =
      if policy
        @model.states.map do |state|
          @model.actions(state).index(policy[state])
        end
      else
        [0] * @model.num_states
      end

    raise 'some initial values are missing' if
      @array_value.any?(&:nil?)
    raise 'some initial policy actions are missing' if
      @array_policy.any?(&:nil?)

    @policy_A = nil
  end

  #
  # @return [ArrayModel] the model being solved; read only; do not change the
  #         model while it is being solved
  #
  attr_reader :model

  #
  # Current value estimate for each state.
  #
  # The result is converted from the solver's internal representation, so you
  # cannot affect the solver by changing the result.
  #
  # @return [Hash<state, Float>] from states to values; read only; any changes
  # made to the returned object will not affect the solver
  #
  def value
    Hash[model.states.zip(@array_value)]
  end

  #
  # Current state-action value estimates; whereas {#value} returns $V(s)$, this
  # returns $Q(s,a)$, in the usual notation.
  #
  # @return [Hash<[state, action], Float>]
  #
  def state_action_value
    q = {}
    model.states.each_with_index do |state, state_n|
      model.actions(state).each_with_index do |action, action_n|
        q_sa = model.array[state_n][action_n].map do |next_state_n, pr, r|
          pr * (r + @discount * @array_value[next_state_n])
        end.inject(:+)
        q[[state, action]] = q_sa
      end
    end
    q
  end

  #
  # Current estimate of the optimal action for each state.
  #
  # @return [Hash<state, action>] from states to actions; read only; any changes
  # made to the returned object will not affect the solver
  #
  def policy
    Hash[model.states.zip(@array_policy).map do |state, action_n|
      [state, model.actions(state)[action_n]]
    end]
  end

  #
  # Refine the estimate of the value function for the current policy. This is
  # done by iterating the Bellman equations; see also {#evaluate_policy_exact}
  # for a different approach.
  #
  # This is the 'policy evaluation' step in Figure 4.3 of Sutton and Barto
  # (1998).
  #
  # @return [Float] largest absolute change (over all states) in the value
  # function
  #
  def evaluate_policy
    delta = 0.0
    model.array.each_with_index do |actions, state_n|
      next_state_ns = actions[@array_policy[state_n]]
      new_value = backup(next_state_ns)
      delta = [delta, (@array_value[state_n] - new_value).abs].max
      @array_value[state_n] = new_value
    end
    delta
  end

  #
  # Evaluate the value function for the current policy by solving a linear
  # system of n equations in n unknowns, where n is the number of states in the
  # model.
  #
  # This routine currently uses dense linear algebra, so it requires that the
  # full n-by-n matrix be stored in memory. This may be a problem for moderately
  # large n.
  #
  # All of the coefficients (A and b in Ax = b) are computed first call, but
  # subsequent calls recompute only those rows for which the policy has changed
  # since the last call.
  #
  # @return [nil]
  #
  def evaluate_policy_exact
    if @policy_A
      # update only those rows for which the policy has changed
      @policy_A_action.zip(@array_policy)
        .each_with_index do |(old_action_n, new_action_n), state_n|
        next if old_action_n == new_action_n
        update_policy_Ab state_n, new_action_n
      end
    else
      # initialise the A and the b for Ax = b
      num_states = model.num_states
      @policy_A = NMatrix.float(num_states, num_states)
      @policy_A_action = [-1] * num_states
      @policy_b = NVector.float(num_states)

      @array_policy.each_with_index do |action_n, state_n|
        update_policy_Ab state_n, action_n
      end
    end

    value = @policy_b / @policy_A # solve linear system
    @array_value = value.to_a
    nil
  end

  #
  # Make policy greedy with respect to the current value function.
  #
  # This is the 'policy improvement' step in Figure 4.3 of Sutton and Barto
  # (1998).
  #
  # @return [Boolean] false iff the policy changed for any state
  #
  def improve_policy
    stable = true
    model.array.each_with_index do |actions, state_n|
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
      stable = false if @array_policy[state_n] != a_max
      @array_policy[state_n] = a_max
    end
    stable
  end

  #
  # A single iteration of value iteration.
  #
  # This is the algorithm from Figure 4.5 of Sutton and Barto (1998). It is
  # mostly equivalent to calling {#evaluate_policy} and then {#improve_policy},
  # but it is somewhat more efficient.
  #
  # @return [Float] largest absolute change (over all states) in the value
  # function
  #
  def value_iteration_single
    delta = 0.0
    model.array.each_with_index do |actions, state_n|
      a_max = nil
      v_max = -Float::MAX
      actions.each_with_index do |next_state_ns, action_n|
        v = backup(next_state_ns)
        if v > v_max
          a_max = action_n
          v_max = v
        end
      end
      delta = [delta, (@array_value[state_n] - v_max).abs].max
      @array_value[state_n] = v_max
      @array_policy[state_n] = a_max
    end
    delta
  end

  #
  # Value iteration; call {#value_iteration_single} up to
  # <tt>max_iters</tt> times until the largest change in the value function
  # (<tt>delta</tt>) is less than <tt>tolerance</tt>.
  #
  # @param [Float] tolerance small positive number
  #
  # @param [Integer, nil] max_iters terminate after this many iterations, even
  #        if the value function has not converged; nil means that there is
  #        no limit on the number of iterations
  #
  # @return [Boolean] true iff iteration converged to within tolerance
  #
  # @yield [num_iters, delta] at the end of each iteration
  #
  # @yieldparam [Integer] num_iters iterations done so far
  #
  # @yieldparam [Float] delta largest change in the value function in the last
  #             iteration
  #
  def value_iteration(tolerance, max_iters = nil)
    delta = Float::MAX
    num_iters = 0
    loop do
      delta = value_iteration_single
      num_iters += 1

      break if delta < tolerance
      break if max_iters && num_iters >= max_iters
      yield num_iters, delta if block_given?
    end
    delta < tolerance
  end

  #
  # Solve with policy iteration using approximate (iterative) policy evaluation.
  #
  # @param [Float] value_tolerance small positive number; the policy evaluation
  #        phase ends if the largest change in the value function
  #        (<tt>delta</tt>) is below this tolerance
  #
  # @param [Integer, nil] max_value_iters terminate the policy evaluation
  #        phase after this many iterations, even if the value function has not
  #        converged; nil means that there is no limit on the number of
  #        iterations in each policy evaluation phase
  #
  # @param [Integer, nil] max_policy_iters terminate after this many
  #        iterations, even if a stable policy has not been obtained; nil means
  #        that there is no limit on the number of iterations
  #
  # @return [Boolean] true iff a stable policy was obtained
  #
  # @yield [num_policy_iters, num_value_iters, delta] at the end of each
  #        policy evaluation iteration
  #
  # @yieldparam [Integer] num_policy_iters policy improvement iterations done so
  #             far
  #
  # @yieldparam [Integer] num_value_iters policy evaluation iterations done so
  #             far for the current policy improvement iteration
  #
  # @yieldparam [Float] delta largest change in the value function in the last
  #             policy evaluation iteration
  #
  def policy_iteration(value_tolerance, max_value_iters = nil,
    max_policy_iters = nil)

    stable = false
    num_policy_iters = 0
    loop do
      # policy evaluation
      num_value_iters = 0
      loop do
        value_delta = evaluate_policy
        num_value_iters += 1

        break if value_delta < value_tolerance
        break if max_value_iters && num_value_iters >= max_value_iters
        yield num_policy_iters, num_value_iters, value_delta if block_given?
      end

      # policy improvement
      stable = improve_policy
      num_policy_iters += 1
      break if stable
      break if max_policy_iters && num_policy_iters >= max_policy_iters
    end
    stable
  end

  #
  # Solve with policy iteration using exact policy evaluation.
  #
  # @param [Integer, nil] max_iters terminate after this many
  #        iterations, even if a stable policy has not been obtained; nil means
  #        that there is no limit on the number of iterations
  #
  # @return [Boolean] true iff a stable policy was obtained
  #
  # @yield [num_iters] at the end of each iteration
  #
  # @yieldparam [Integer] num_iters policy improvement iterations done so far
  #
  def policy_iteration_exact(max_iters = nil)
    stable = false
    num_iters = 0
    loop do
      evaluate_policy_exact
      stable = improve_policy
      num_iters += 1
      break if stable
      break if max_iters && num_iters >= max_iters
      yield num_iters if block_given?
    end
    stable
  end

  private

  #
  # Updated value estimate for a state with the given successor states.
  #
  def backup(next_state_ns)
    next_state_ns.map do |next_state_n, probability, reward|
      probability * (reward + @discount * @array_value[next_state_n])
    end.inject(:+)
  end

  #
  # Update the row in A the entry in b (in Ax=b) for the given state; see
  # {#evaluate_policy_exact}.
  #
  def update_policy_Ab(state_n, action_n)
    # clear out the old values for state_n's row
    @policy_A[true, state_n] = 0.0

    # set new values according to state_n's successors under the current policy
    b_n = 0
    next_state_ns = model.array[state_n][action_n]
    next_state_ns.each do |next_state_n, probability, reward|
      @policy_A[next_state_n, state_n] = -@discount * probability
      b_n += probability * reward
    end
    @policy_A[state_n, state_n] += 1
    @policy_A_action[state_n] = action_n
    @policy_b[state_n] = b_n
  end
end
