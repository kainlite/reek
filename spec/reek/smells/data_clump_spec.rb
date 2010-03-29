require File.join(File.dirname(File.dirname(File.dirname(File.expand_path(__FILE__)))), 'spec_helper')
require File.join(File.dirname(File.dirname(File.dirname(File.dirname(File.expand_path(__FILE__))))), 'lib', 'reek', 'smells', 'data_clump')
require File.join(File.dirname(File.expand_path(__FILE__)), 'smell_detector_shared')

include Reek::Smells

shared_examples_for 'a data clump detector' do
  it 'does not report small parameter sets' do
    src = <<EOS
# test module
#{@context} Scrunch
  def first(pa) @field == :sym ? 0 : 3; end
  def second(pa) @field == :sym; end
  def third(pa) pa - pb + @fred; end
end
EOS

    src.should_not reek
  end

  context 'with 3 identical pairs' do
    before :each do
      @module_name = 'Scrunch'
      @src = <<EOS
#{@context} #{@module_name}
  def first(pa, pb) @field == :sym ? 0 : 3; end
  def second(pa, pb) @field == :sym; end
  def third(pa, pb) pa - pb + @fred; end
end
EOS
      ctx = CodeContext.new(nil, @src.to_reek_source.syntax_tree)
      detector = DataClump.new('newt')
      detector.examine(ctx)
      @smells = detector.smells_found.to_a
      @warning = @smells[0]   # SMELL: too cumbersome!
      @yaml = @warning.to_yaml
    end
    it 'records only the one smell' do
      @smells.length.should == 1
    end
    it 'reports all parameters' do
      @smells[0].smell[DataClump::PARAMETERS_KEY].should == ['pa', 'pb']
    end
    it 'reports the number of occurrences' do
      @smells[0].smell['occurrences'].should == 3
    end
    it 'reports all parameters' do
      @smells[0].smell[DataClump::METHODS_KEY].should == ['first', 'second', 'third']
    end
    it 'reports the declaration line numbers' do
      @smells[0].lines.should == [2,3,4]
    end
    it 'reports the correct smell class' do
      @smells[0].smell_class.should == DataClump::SMELL_CLASS
    end
    it 'reports the context fq name' do
      @smells[0].context.should == @module_name
    end
  end

  it 'reports 3 swapped pairs in a class' do
    src = <<EOS
#{@context} Scrunch
  def one(pa, pb) @field == :sym ? 0 : 3; end
  def two(pb, pa) @field == :sym; end
  def tri(pa, pb) pa - pb + @fred; end
end
EOS

    src.should reek_of(:DataClump, /\[pa, pb\]/, /3 methods/)
  end

  it 'reports 3 identical parameter sets in a class' do
    src = <<EOS
#{@context} Scrunch
  def first(pa, pb, pc) @field == :sym ? 0 : 3; end
  def second(pa, pb, pc) @field == :sym; end
  def third(pa, pb, pc) pa - pb + @fred; end
end
EOS

    src.should reek_of(:DataClump, /\[pa, pb, pc\]/, /3 methods/)
    src.should_not reek_of(:DataClump, /\[pa, pb\]/, /3 methods/)
    src.should_not reek_of(:DataClump, /\[pa, pc\]/, /3 methods/)
    src.should_not reek_of(:DataClump, /\[pb, pc\]/, /3 methods/)
  end

  it 'recognises re-ordered identical parameter sets' do
    src = <<EOS
#{@context} Scrunch
  def first(pb, pa, pc) @field == :sym ? 0 : 3; end
  def second(pc, pb, pa) @field == :sym; end
  def third(pa, pb, pc) pa - pb + @fred; end
end
EOS

    src.should reek_of(:DataClump, /\[pa, pb, pc\]/, /3 methods/)
    src.should_not reek_of(:DataClump, /\[pa, pb\]/, /3 methods/)
    src.should_not reek_of(:DataClump, /\[pa, pc\]/, /3 methods/)
    src.should_not reek_of(:DataClump, /\[pb, pc\]/, /3 methods/)
  end

  it 'counts only identical parameter sets' do
    src = <<EOS
#{@context} RedCloth
  def fa(p1, p2, p3, conten) end
  def fb(p1, p2, p3, conten) end
  def fc(name, windowW, windowH) end
end
EOS

    src.should_not reek_of(:DataClump)
  end
end

describe DataClump do
  context 'in a class' do
    before :each do
      @context = 'class'
    end

    it_should_behave_like 'a data clump detector'
  end

  context 'in a module' do
    before :each do
      @context = 'module'
    end

    it_should_behave_like 'a data clump detector'
  end

  # TODO: include singleton methods in the calcs
end

describe DataClump do
  before(:each) do
    @detector = DataClump.new('newt')
  end

  it_should_behave_like 'SmellDetector'

  it 'get a real example right' do
    src = <<-EOS
module Inline
  def generate(src, options) end
  def c (src, options) end
  def c_singleton (src, options) end
  def c_raw (src, options) end
  def c_raw_singleton (src, options) end
end
EOS
    ctx = CodeContext.new(nil, src.to_reek_source.syntax_tree)
    detector = DataClump.new('newt')
    detector.examine(ctx)
    smells = detector.smells_found.to_a
    smells.length.should == 1
    warning = smells[0]
    warning.smell[DataClump::OCCURRENCES_KEY].should == 5
  end
end

#---------------------------------------------------------------------------------
#
#def occurrences(potential_clump, all_methods)
#  all_methods.select do |method|
#    potential_clump - method == []
#  end.length
#end
#
#describe 'occurrences' do
#  it 'counts correctly' do
#    params = [[:a1, :a2], [:a1, :a2]]
#    potential_clump = [:a1, :a2]
#    occurrences(potential_clump, params).should == 2
#  end
#end
#
#def immediate_clumps(root, other_params, all_methods)
#  result = []
#  other_params.map do |param|
#    potential_clump = (root + [param])
#    if occurrences(potential_clump, all_methods) >= 2
#      result << potential_clump
#      result = result + immediate_clumps(potential_clump, other_params - [param], all_methods)
#    end
#  end.compact
#  result
#end
#
#def clumps_containing(root, other_params, all_methods)
#  return [] unless other_params
#  immediate_clumps(root, other_params, all_methods) + clumps_containing([other_params[0]], other_params[1..-1], all_methods)
#end
#
#def clumps_in(all_methods)
#  all_params = all_methods.flatten.sort {|a,b| a.to_s <=> b.to_s}.uniq
#  clumps_containing([all_params[0]], all_params[1..-1], all_methods)
#end
#
#describe 'set of parameters' do
#  it 'finds the trivial clump' do
#    params = [[:a1, :a2], [:a1, :a2]]
#    clumps_in(params).should == [[:a1, :a2]]
#  end
#
#  it 'finds the trivial size-3 clump' do
#    params = [[:a1, :a2, :a3], [:a1, :a2, :a3]]
#    clumps_in(params).should == [[:a1, :a2, :a3]]
#  end
#
#  it 'doesnt find non clump' do
#    params = [[:a1, :a2], [:a1, :a3]]
#    clumps_in(params).should == []
#  end
#
#  it 'finds the trivial sub-clump' do
#    params = [[:a1, :a2], [:a3, :a1, :a2]]
#    clumps_in(params).should == [[:a1, :a2]]
#  end
#
#  it 'finds the non-a1 clump' do
#    params = [[:a1, :a3, :a2], [:a3, :a2]]
#    clumps_in(params).should == [[:a2, :a3]]
#  end
#end
