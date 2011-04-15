require 'test/unit'
require 'finite_mdp'
require 'set'

class TestFiniteMDP < Test::Unit::TestCase
  include FiniteMDP

  #
  # Example 3.7 from Sutton and Barto (1998).
  #
  def test_recycling_robot
    alpha    = 0.1
    beta     = 0.1
    r_search = 2
    r_wait   = 1
    r_rescue = -3

    model = TableModel.new [
      [:high, :search,   :high, alpha,   r_search],
      [:high, :search,   :low,  1-alpha, r_search],
      [:low,  :search,   :high, 1-beta,  r_rescue],
      [:low,  :search,   :low,  beta,    r_search],
      [:high, :wait,     :high, 1,       r_wait],
      [:high, :wait,     :low,  0,       r_wait],
      [:low,  :wait,     :high, 0,       r_wait],
      [:low,  :wait,     :low,  1,       r_wait],
      [:low,  :recharge, :high, 1,       0],
      [:low,  :recharge, :low,  0,       0]]

    assert_equal Set[:high, :low],    Set[*model.states]
    assert_equal Set[:search, :wait], Set[*model.actions(:high)]
    assert_equal Set[:search, :wait, :recharge], Set[*model.actions(:low)]

    p model.next_states(:low, :search)

    solver = Solver.new(model, 0.95, Hash.new(:wait))
    100.times do
    p solver.value
    p solver.policy
    p solver.evaluate_policy
    p solver.improve_policy
    p solver.one_value_iteration
    end

    #sparse_model = NumericModel.from_model(model)

    #assert_equal Set[[:high, alpha], [:low, 1-alpha]],
    #  Set[*model.next_states(:high, :search)]
    #assert_equal Set[[:high, 1], [:low, 0]],
    #  Set[*model.next_states(:high, :wait)]

    #assert_equal {:high => [1-beta, r_], [:low, beta]],
    #  Set[*model.next_states(:low, :search)]
    #assert_equal Set[[:high, 0], [:low, 1]],
    #  Set[*model.next_states(:low, :wait)]
    #assert_equal Set[[:high, 1], [:low, 0]],
    #  Set[*model.next_states(:low, :recharge)]
  end
end

