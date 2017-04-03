################################################################################
#                                                                              #
#                                                                              #
#                  Angel Investments Monte Carlo Simulation                    #
#                                                                              #
#                                                                              #
################################################################################

require 'active_support'
require 'active_support/core_ext'
require 'date'
require 'xirr'
require 'histogram/array'
require 'gruff'

module Probability
  def self.rand_uniform a, b
    lambda {|x| rand(a..b)}
  end

  def self.linear min, p_min, max, p_max
    lin_fun((min..max), p_min, p_max).call(rand(min..max))
  end

  def self.lin_fun range, y0, y1
    x0, x1 = range.min, range.max
    a = 1.0 * (y1 - y0)/(x1 - x0)
    b = (y0*x1 - y1*x0)/(x1 - x0)
    lambda{|x| a*x + b}
  end

  def self.rand_triang min, max, peak
    min, max, peak = min.to_f, max.to_f, peak.to_f
    threshold = (peak - min)/(max - min)
    lambda do |x|
      if x < threshold
        min + Math.sqrt(x * (max - min) * (peak - min))
      else
        max - Math.sqrt((1 - x) * (max - min) * (max - peak))
      end
    end
  end
end

module Wiltbank
    POWER_LOG_HYPOTHESIS = {
      (0.0..0.5) =>   {multip: Probability.lin_fun((0.0..0.5), 0, 0),
                       exit_y: Probability.rand_uniform(1, 5)},                # exits in years 1 to 5 randomly
      (0.5..0.69) =>  {multip: Probability.lin_fun((0.5..0.69), 0, 1),
                       exit_y: Probability.rand_uniform(1, 5)},                # exits in years 1 to 5 randomly
      (0.69..0.87) => {multip: Probability.lin_fun((0.69..0.87), 1, 5),
                       exit_y: Probability.rand_uniform(1, 15)},               # exits in years 1 to 5 randomly
      (0.87..0.94) => {multip: Probability.lin_fun((0.87..0.94), 5, 10),
                       exit_y: Probability.rand_uniform(3, 15)},               # exits in years 3 to 15 randomly
      (0.94..0.98) => {multip: Probability.lin_fun((0.94..0.98), 10, 30),
                       exit_y: Probability.rand_triang(7, 12, 8)},             # exits in years 7 to 12, max prob at 9
      (0.98..1.0) =>  {multip: Probability.lin_fun((0.98..1.0),  30, 1000),
                       exit_y: Probability.rand_triang(10, 17, 10)}}           # exits 10 - 17, max in year 17
end

module Portfolio
  include Xirr
  include Wiltbank
  attr_accessor :bins

  PORTFOLIO_SIZE = 20                                                          # Investments in portfolio
  INVEST_PERIOD   = 5                                                          # First n years when investments are made
  N_BETS_YEAR = PORTFOLIO_SIZE / INVEST_PERIOD                                 # <== has to be divisible (% 0)

  def initialize
    @bins = Wiltbank::POWER_LOG_HYPOTHESIS
  end

  def investment_in year
    trans = [Xirr::Transaction.new(-1, date: Date.new(2016+year))]                # initial investment
    x = rand
    @bins.each do |bin, λ|
      if bin.include? x
        cash_flow = λ[:multip].call(x)
        exit_year = Date.new(2016 + year + λ[:exit_y].call(rand))
        trans << Xirr::Transaction.new(cash_flow, date: exit_year)
      end
    end
    trans
  end

  def portfolio_irr
    cf = Xirr::Cashflow.new
    INVEST_PERIOD.times do |year|
      N_BETS_YEAR.times do
        cf.concat investment_in(year)
      end
    end

    begin
      cf.xirr guess: -0.1
    rescue
      puts "oops!"  # not terrible 3 per 100k
      0.0
    end
  end
end

module Report
  BIN_WIDTH = 1
  COLOR_RED = '#F1948A'
  COLOR_YLW = '#FDEEBD'
  COLOR_GRN = '#DAF7A6'
  COLOR_BLU = '#D6EAF8'

  def self.histogram irr_data, stats
    (bins, freqs) = irr_data.histogram :bin_width => BIN_WIDTH

    g = Gruff::Bar.new(800)
    g.hide_legend = true
    g.title_font_size = 24
    g.title = stats
    g.hide_line_markers = true

    bins.size.times { |i| g.data(bins[i], freqs[i], colorize(bins[i])) }
    g.write('./images/exciting.png')
  end

  def self.colorize bin
    case bin
    when (-100..0) then COLOR_RED
    when (0...20)  then COLOR_YLW
    when (20..80)  then COLOR_BLU
    else COLOR_GRN
    end
  end
end

class AngelSim
  include Portfolio
  include Report

  NUMBER_CYCLES = 10_000

  def chart
    data = []
    NUMBER_CYCLES.times { data << (100 * portfolio_irr).round(3) }
    z = data.count

    ap = accum_prob data
    stats = "Mean: #{(data.sum/z).round(1)}% \
    StDev: #{Math.sqrt(data.inject(0, :+){|r| (r-avg)**2}/(z-1)).round(1)} \
    \nIRR [<0% #{ap[0]}%] [0-20% = #{ap[1]}%] [20-80% = #{ap[2]}%] [>80% = #{ap[3]}%]"
    Report.histogram data, stats
  end

  def accum_prob irrs
    z = irrs.count
    [irrs.count{|r| r < 0.0},
     irrs.count{|r| (0..20.0).include? r},
     irrs.count{|r| (20..80.0).include? r},
     irrs.count{|r| r > 80.0}].map{|r| (100.0 * r/z).round}
  end
end

# Uncomment to run
AngelSim.new.chart
