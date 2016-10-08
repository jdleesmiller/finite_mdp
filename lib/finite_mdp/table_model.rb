# frozen_string_literal: true
#
# A finite markov decision process model for which the states, actions,
# transition probabilities and rewards are specified as a table. This is a
# common way of specifying small models.
#
# The states and actions can be arbitrary objects; see notes for {Model}.
#
class FiniteMDP::TableModel
  include FiniteMDP::Model

  #
  # @param [Array<[state, action, state, Float, Float]>] rows each row is
  #  [state, action, next state, probability, reward]
  #
  def initialize(rows)
    @rows = rows
  end

  #
  # @return [Array<[state, action, state, Float, Float]>] each row is [state,
  #  action, next state, probability, reward]
  #
  attr_accessor :rows

  #
  # States in this model; see {Model#states}.
  #
  # @return [Array<state>] not empty; no duplicate states
  #
  def states
    @rows.map { |row| row[0] }.uniq
  end

  #
  # Actions that are valid for the given state; see {Model#actions}.
  #
  # @param [state] state
  #
  # @return [Array<action>] not empty; no duplicate actions
  #
  def actions(state)
    @rows.map { |row| row[1] if row[0] == state }.compact.uniq
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
  def next_states(state, action)
    @rows.map { |row| row[2] if row[0] == state && row[1] == action }.compact
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
  # @return [Float] in [0, 1]; zero if the transition is not in the table
  #
  def transition_probability(state, action, next_state)
    row = find_row(state, action, next_state)
    row ? row[3] : 0
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
  # @return [Float, nil] nil if the transition is not in the table
  #
  def reward(state, action, next_state)
    row = find_row(state, action, next_state)
    row[4] if row
  end

  #
  # @return [String] can be quite large
  #
  def inspect
    rows.map(&:inspect).join("\n")
  end

  #
  # Convert any model into a table model.
  #
  # @param [Model] model
  #
  # @param [Boolean] sparse do not store rows for transitions with zero
  #        probability
  #
  # @return [TableModel]
  #
  def self.from_model(model, sparse = true)
    rows = []
    model.states.each do |state|
      model.actions(state).each do |action|
        model.next_states(state, action).each do |next_state|
          pr = model.transition_probability(state, action, next_state)
          next unless pr > 0 || !sparse
          reward = model.reward(state, action, next_state)
          rows << [state, action, next_state, pr, reward]
        end
      end
    end
    FiniteMDP::TableModel.new(rows)
  end

  private

  def find_row(state, action, next_state)
    @rows.find do |row|
      row[0] == state && row[1] == action && row[2] == next_state
    end
  end
end
