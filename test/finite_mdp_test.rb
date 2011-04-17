# uncomment for coverage in ruby 1.9
#require 'simplecov'
#SimpleCov.start

require 'test/unit'
require 'finite_mdp'
require 'set'

#
# An example model for testing; taken from Russel, Norvig (2003). Artificial
# Intelligence: A Modern Approach, Chapter 17.
#
# See http://aima.cs.berkeley.edu/python/mdp.html for a Python implementation.
#
class AIMAGridModel
  include FiniteMDP::Model

  def initialize grid, terminii
    @grid = grid
    @terminii = terminii
  end

  attr_reader :grid, :terminii

  # states every position on the grid is a state, except for obstacles, which
  # are indicated by nil
  def states
    0.upto(grid.size-1).map{|i|
      0.upto(grid[i].size-1).map{|j|
        [i,j] if grid[i][j]
      }
    }.flatten(1).compact + [:stop]
  end

  # agent can move north, east, south or west
  MOVE_N = [-1,  0]
  MOVE_E = [ 0,  1]
  MOVE_S = [ 1,  0]
  MOVE_W = [ 0, -1]

  # when the agent tries to move forward, it usually succeeds, but it may move
  # left or right instead
  MOVES = {
    MOVE_N => {MOVE_N => 0.8, MOVE_E => 0.1, MOVE_W => 0.1},
    MOVE_E => {MOVE_E => 0.8, MOVE_N => 0.1, MOVE_S => 0.1},
    MOVE_S => {MOVE_S => 0.8, MOVE_E => 0.1, MOVE_W => 0.1},
    MOVE_W => {MOVE_W => 0.8, MOVE_N => 0.1, MOVE_S => 0.1}
  }

  # agent can take any action in any state; if it tries to move into an obstacle
  # or off the grid, it stays where it is
  def actions state
    if state == :stop || terminii.member?(state)
      [:stop]
    else
      MOVES.keys
    end
  end

  # transition probabilities are based on MOVES; we just have to make sure that
  # we stay on the grid
  def transition_probability state, action, next_state
    if state == :stop || terminii.member?(state)
      (action == :stop && next_state == :stop) ? 1 : 0
    else
      MOVES[action].map {|m, pr|
        m_state = [state[0] + m[0], state[1] + m[1]]
        m_state = state unless states.member?(m_state)
        pr if m_state == next_state
      }.compact.inject(:+) || 0
    end
  end

  # reward is given by the grid cells; no reward for terminal states
  def reward state, action, next_state
    state == :stop ? 0 : grid[state[0]][state[1]]
  end

  def hash_to_grid hash
    0.upto(grid.size-1).map {|i| 0.upto(grid[i].size-1).map {|j| hash[[i,j]] }}
  end

  def pretty_value value, io=STDOUT
    hash_to_grid(Hash[value.map {|s, v| [s, "%+.3f" % v]}]).map{|row|
      row.map{|cell| cell || '      '}.join(' ')}
  end

  def pretty_policy policy
    symbols = {MOVE_N => '^', MOVE_E => '>', MOVE_S => 'v', MOVE_W => '<'}
    hash_to_grid(Hash[policy.map {|s, a| [s, symbols[a]]}]).map{|row|
      row.map{|cell| cell || ' '}.join(' ')}
  end
end

class TestFiniteMDP < Test::Unit::TestCase
  include FiniteMDP

  # check that we get the same model back; model parameters must be set before
  # calling; see test_recycling_robot
  def check_recycling_robot_model model, sparse
    model.check_transition_probabilities_sum

    assert_equal Set[:high, :low],    Set[*model.states]
    assert_equal Set[:search, :wait], Set[*model.actions(:high)]
    assert_equal Set[:search, :wait, :recharge], Set[*model.actions(:low)]

    if sparse
      assert_equal [:low],  model.next_states(:low, :wait)
      assert_equal [:high], model.next_states(:low, :recharge)
      assert_equal [:high], model.next_states(:high, :wait)
    else
      assert_equal Set[:high, :low],  Set[*model.next_states(:low, :wait)]
      assert_equal Set[:high, :low],  Set[*model.next_states(:low, :recharge)]
      assert_equal Set[:high, :low],  Set[*model.next_states(:high, :wait)]
    end
    assert_equal Set[:high, :low],    Set[*model.next_states(:low, :search)]
    assert_equal Set[:high, :low],    Set[*model.next_states(:high, :search)]

    assert_equal 1-@beta, model.transition_probability(:low, :search, :high)
    assert_equal   @beta, model.transition_probability(:low, :search, :low)
    assert_equal       0, model.transition_probability(:low, :wait, :high)
    assert_equal       1, model.transition_probability(:low, :wait, :low)
    assert_equal       1, model.transition_probability(:low, :recharge, :high)
    assert_equal       0, model.transition_probability(:low, :recharge, :low)

    assert_equal   @alpha, model.transition_probability(:high, :search, :high)
    assert_equal 1-@alpha, model.transition_probability(:high, :search, :low)
    assert_equal        1, model.transition_probability(:high, :wait, :high)
    assert_equal        0, model.transition_probability(:high, :wait, :low)

    assert_equal @r_rescue, model.reward(:low, :search, :high)
    assert_equal @r_search, model.reward(:low, :search, :low)
    assert_equal   @r_wait, model.reward(:low, :wait, :low)
    assert_equal         0, model.reward(:low, :recharge, :high)

    assert_equal @r_search, model.reward(:high, :search, :high)
    assert_equal @r_search, model.reward(:high, :search, :low)
    assert_equal   @r_wait, model.reward(:high, :wait, :high)

    if sparse
      assert_equal     nil, model.reward(:low, :wait, :high)
      assert_equal     nil, model.reward(:low, :recharge, :low)
      assert_equal     nil, model.reward(:high, :wait, :low)
    else
      assert_equal @r_wait, model.reward(:low, :wait, :high)
      assert_equal       0, model.reward(:low, :recharge, :low)
      assert_equal @r_wait, model.reward(:high, :wait, :low)
    end
  end

  #
  # Example 3.7 from Sutton and Barto (1998).
  #
  def test_recycling_robot
    @alpha    = 0.1
    @beta     = 0.1
    @r_search = 2
    @r_wait   = 1
    @r_rescue = -3

    table_model = TableModel.new [
      [:high, :search,   :high, @alpha,   @r_search],
      [:high, :search,   :low,  1-@alpha, @r_search],
      [:low,  :search,   :high, 1-@beta,  @r_rescue],
      [:low,  :search,   :low,  @beta,    @r_search],
      [:high, :wait,     :high, 1,        @r_wait],
      [:high, :wait,     :low,  0,        @r_wait],
      [:low,  :wait,     :high, 0,        @r_wait],
      [:low,  :wait,     :low,  1,        @r_wait],
      [:low,  :recharge, :high, 1,        0],
      [:low,  :recharge, :low,  0,        0]]

    assert_equal 10, table_model.rows.size

    # check round trips for different model formats; don't sparsify yet
    check_recycling_robot_model table_model, false
    check_recycling_robot_model TableModel.from_model(table_model, false), false

    hash_model = HashModel.from_model(table_model, false)
    check_recycling_robot_model hash_model, false
    check_recycling_robot_model TableModel.from_model(hash_model, false), false

    # if we sparsify, we should lose some rows
    sparse_table_model = TableModel.from_model(table_model)
    assert_equal 7, sparse_table_model.rows.size
    check_recycling_robot_model sparse_table_model, true

    sparse_hash_model = HashModel.from_model(table_model)
    check_recycling_robot_model sparse_hash_model, true

    # once they're gone, they don't come back
    sparse_hash_model = HashModel.from_model(sparse_table_model, false)
    check_recycling_robot_model sparse_hash_model, true

    # try solving with value iteration
    solver = Solver.new(table_model, 0.95, Hash.new {:wait})
    assert solver.value_iteration(1e-4, 200), "did not converge"
    assert_equal({:high => :search, :low => :recharge}, solver.policy)

    # try solving with policy iteration using iterative policy evaluation
    solver = Solver.new(table_model, 0.95, Hash.new {:wait})
    assert solver.policy_iteration(1e-4, 2, 20), "did not find stable policy"
    assert_equal({:high => :search, :low => :recharge}, solver.policy)

    # try solving with policy iteration using exact policy evaluation
    solver = Solver.new(table_model, 0.95, Hash.new {:wait})
    assert solver.policy_iteration_exact(20), "did not find stable policy"
    assert_equal({:high => :search, :low => :recharge}, solver.policy)
  end

  def check_grid_solutions model, pretty_policy
    # solve with policy iteration (approximate policy evaluation)
    solver = Solver.new(model, 1)
    assert solver.policy_iteration(1e-5, 10, 50), "did not converge"
    assert_equal pretty_policy, model.pretty_policy(solver.policy)

    # solve with policy (exact policy evaluation)
    solver = Solver.new(model, 0.9999) # discount 1 gives singular matrix
    assert solver.policy_iteration_exact(20), "did not converge"
    assert_equal pretty_policy, model.pretty_policy(solver.policy)

    # solve with value iteration
    solver = Solver.new(model, 1)
    assert solver.value_iteration(1e-5, 100), "did not converge"
    assert_equal pretty_policy, model.pretty_policy(solver.policy)

    solver
  end

  def test_aima_grid_1
    # the grid from Figures 17.1, 17.2 and 17.3 (just flipped y axis)
    model = AIMAGridModel.new(
      [[-0.04, -0.04, -0.04,    +1],
       [-0.04,   nil, -0.04,    -1],
       [-0.04, -0.04, -0.04, -0.04]],
       [[0, 3], [1, 3]]) # terminals (the +1 and -1 states)
    model.check_transition_probabilities_sum

    assert_equal Set[
      [0, 0], [0, 1], [0, 2], [0, 3],
      [1, 0],         [1, 2], [1, 3],
      [2, 0], [2, 1], [2, 2], [2, 3], :stop], Set[*model.states]

    assert_equal Set[[0, -1], [0, 1], [-1, 0], [1, 0]],
      Set[*model.actions([0, 0])]
    assert_equal [:stop], model.actions([1, 3])
    assert_equal [:stop], model.actions(:stop)

    # check policy against Figure 17.2(a)
    solver = check_grid_solutions model,
      ["> > >  ",
       "^   ^  ", 
       "^ < < <"]

    # check the actual (non-pretty) policy
    assert_equal [
      [[ 0, 1], [0,  1], [ 0, 1],   :stop],
      [[-1, 0],     nil, [-1, 0],   :stop],
      [[-1, 0], [0, -1], [0, -1], [0, -1]]], model.hash_to_grid(solver.policy)

    # check values against Figure 17.3
    assert [[0.812, 0.868, 0.918,     1],
            [0.762,   nil, 0.660,    -1],
            [0.705, 0.655, 0.611, 0.388]].flatten.
            zip(model.hash_to_grid(solver.value).flatten).
            all? {|x,y| (x.nil? && y.nil?) || (x-y).abs < 5e-4}
  end

  def test_aima_grid_2
    # a grid from Figure 17.2(b)
    r = -1.7
    model = AIMAGridModel.new(
      [[   r,   r,    r,  +1],
       [   r, nil,    r,  -1],
       [   r,   r,    r,   r]],
       [[0, 3], [1, 3]]) # terminals (the +1 and -1 states)
    model.check_transition_probabilities_sum

    check_grid_solutions model, 
      ["> > >  ",
       "^   >  ", 
       "> > > ^"]
  end

  def test_aima_grid_3
    # a grid from Figure 17.2(b)
    r = -0.3
    model = AIMAGridModel.new(
      [[   r,   r,    r,  +1],
       [   r, nil,    r,  -1],
       [   r,   r,    r,   r]],
       [[0, 3], [1, 3]]) # terminals (the +1 and -1 states)
    model.check_transition_probabilities_sum

    check_grid_solutions model, 
      ["> > >  ",
       "^   ^  ", 
       "^ > ^ <"]
  end

  def test_aima_grid_4
    # a grid from Figure 17.2(b)
    r = -0.01
    model = AIMAGridModel.new(
      [[   r,   r,    r,  +1],
       [   r, nil,    r,  -1],
       [   r,   r,    r,   r]],
       [[0, 3], [1, 3]]) # terminals (the +1 and -1 states)
    model.check_transition_probabilities_sum

    check_grid_solutions model, 
      ["> > >  ",
       "^   <  ", 
       "^ < < v"]
  end

  class TestPoint 
    include FiniteMDP::VectorValued
    def initialize x, y
      @x, @y = x, y
    end
    attr_accessor :x, :y
    # must implement to_a to make VectorValued work.
    def to_a
      [x, y]
    end
  end

  def test_vector_valued
    p1 = TestPoint.new(0, 0)
    p2 = TestPoint.new(0, 1)
    p3 = TestPoint.new(0, 0)

    assert !p1.eql?(p2)
    assert !p3.eql?(p2)
    assert  p1.eql?(p1)
    assert  p1.eql?(p3)
    assert_equal p1.hash, p3.hash
  end
end

