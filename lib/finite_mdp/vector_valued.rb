#
# Define an object's hash code and equality (in the sense of <tt>eql?</tt>)
# according to its array representation (<tt>to_a</tt>). See notes for {Model}
# for why this might be useful.
#
# A class that includes this module must define <tt>to_a</tt>.
#
module FiniteMDP::VectorValued
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

