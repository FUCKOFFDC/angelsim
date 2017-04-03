require 'minitest/autorun'

require_relative './vcm_distributions.rb'

class TestProbability < Minitest::Test
  include Probability

  def test_rand_uniform
    assert_equal 0, Probability.rand_uniform(0, 0).call(rand)
    assert_equal 8, Probability.rand_uniform(8, 8).call(rand)
    assert (-100..100).include?(Probability.rand_uniform(-100.0, 100).call(rand))
  end

  def test_linear_function
    assert_equal 0.3, Probability.lin_fun((0..10), 0, 10).call(0.3)
    assert_equal 9.7, Probability.lin_fun((0..10), 10, 0).call(0.3)
    assert_equal -5,  Probability.lin_fun((-10..10), 0, -10).call(0)
  end

  def test_rand_linear
    assert_equal 7, Probability.linear(0.0, 7, 100, 7)
    assert (7..9).include?(Probability.linear(0.0, 7, 100, 9))
    assert (7..9).include?(Probability.linear(0.0, 9, 100, 7))
  end

  def test_triang_distribution
    tot = 1_000_000
    sum = 0.0
    tot.times { sum += Probability.rand_triang(0, 10, 5).call(rand) }
    assert_in_delta 5, sum/tot, 0.01
  end
end

