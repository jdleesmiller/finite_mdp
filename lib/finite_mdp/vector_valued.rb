# frozen_string_literal: true
#
# Define an object's hash code and equality (in the sense of <tt>eql?</tt>)
# according to its array representation (<tt>to_a</tt>). See notes for {Model}
# for why this might be useful.
#
# A class that includes this module must define <tt>to_a</tt>.
#
# @example
#
#   class MyPoint
#     include FiniteMDP::VectorValued
#
#     def initialize x, y
#       @x, @y = x, y
#     end
#
#     attr_accessor :x, :y
#
#     # must implement to_a to make VectorValued work
#     def to_a
#       [x, y]
#     end
#   end
#
#   MyPoint.new(0, 0).eql?(MyPoint.new(0, 0)) #=> true as expected
#
module FiniteMDP::VectorValued
  #
  # Redefine hashing based on +to_a+.
  #
  # @return [Integer]
  #
  def hash
    to_a.hash
  end

  #
  # Redefine equality based on +to_a+.
  #
  # @return [Boolean]
  #
  def eql?(other)
    to_a.eql? other.to_a
  end
end
