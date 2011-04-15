module FiniteMDP::VectorValued
  include Comparable

  #
  # Redefine comparison so we can sort states lexically.
  #
  def <=> state
    self.to_a <=> state.to_a
  end

  #
  # Redefine hashing so we can use states as hash keys.
  #
  def hash
    self.to_a.hash
  end

  #
  # Redefine equality so we can use states as hash keys.
  #
  def eql? state
    self.to_a.eql? state.to_a
  end
end

