require './btree.rb'
require 'colored'

class ExpectionResult
  attr_reader :test_title, :actual_value

  def initialize(test_title, actual_value)
    @test_title = test_title
    @actual_value = actual_value
  end

  def to_be(expected_value)
    if actual_value.send(expected_value)
      puts "--> `#{test_title}` test passed.".green
    else
      puts "--> `#{test_title}` test failed.\nExpected: `#{expected_value}` to return true.".red
    end

    self
  end

  def not_to_be(expected_value)
    unless actual_value.send(expected_value)
      puts "--> `#{test_title}` test passed.".green
    else
      puts "--> `#{test_title}` test failed.\nExpected: `#{expected_value}` to return false.".red
    end

    self
  end

  def to_equal(expected_value)
    if actual_value == expected_value
      puts "--> `#{test_title}` test passed.".green
    else
      puts "--> `#{test_title}` test failed.\nExpected: `#{expected_value}`, \nGot `#{actual_value}`.".red
    end

    self
  end

  def not_to_equal(expected_value)
    if actual_value != expected_value
      puts "--> `#{test_title}` test passed.".green
    else
      puts "--> `#{test_title}` test failed.\nExpected: `#{expected_value}`, \nGot `#{actual_value}`.".red
    end

    self
  end
end

def expect(test_title, &block)
  begin
    ExpectionResult.new test_title, block.call
  rescue => e
    ExpectionResult.new test_title, "Exception raised: `#{e.message}`"
  end
end

# def assert(test_title, expected_value, &block)
#   actual_value = block.call
#
#   if actual_value == expected_value
#     puts "--> `#{test_title}` test passed.".green
#   else
#     puts "--> `#{test_title}` test failed. Expected: `#{expected_value}`, got `#{actual_value}`.".red
#   end
# end

puts "--- Testing add() method ---"

root = BTree.new(10)

expect('Adding 20, 30, 40, 50 should not cause a split') {
  [20, 30, 40, 50].each { |key| root.add key }
  root
}
  .to_be(:valid?)
  .to_equal(
    BTree.new([10, 20, 30, 40, 50])
  )

expect('Adding 60 should split the root node') {
  root.add 60
  root
}.to_equal(
  BTree.new(30, subtrees: [BTree.new([10, 20]), BTree.new([40, 50, 60])])
)

expect('Adding 70, 80 should not cause a split') {
  [70, 80].each { |key| root.add key }
  root
}.to_equal(
  BTree.new(30, subtrees: [BTree.new([10, 20]), BTree.new([40, 50, 60, 70, 80])])
)

expect('Adding 90 should split the right child node') {
  root.add 90
  root
}.to_equal(
  BTree.new([30, 60], subtrees: [BTree.new([10, 20]), BTree.new([40, 50]), BTree.new([70, 80, 90])])
)

puts "--- Testing delete() method ---"

root = BTree.new(
  :P,
  subtrees: [
    BTree.new(
      [:C, :G, :M],
      subtrees: [
        BTree.new([:A, :B]),
        BTree.new([:D, :E, :F]),
        BTree.new([:J, :K, :L]),
        BTree.new([:N, :O])
      ]
    ),
    BTree.new(
      [:T, :X],
      subtrees: [
        BTree.new([:Q, :R, :S]),
        BTree.new([:U, :V]),
        BTree.new([:Y, :Z])
      ]
    )
  ]
)

expect('Deleting F should yield case 1') {
  root.delete :F
  root
}.to_equal(
  BTree.new(
    :P,
    subtrees: [
      BTree.new(
        [:C, :G, :M],
        subtrees: [
          BTree.new([:A, :B]),
          BTree.new([:D, :E]),
          BTree.new([:J, :K, :L]),
          BTree.new([:N, :O])
        ]
      ),
      BTree.new(
        [:T, :X],
        subtrees: [
          BTree.new([:Q, :R, :S]),
          BTree.new([:U, :V]),
          BTree.new([:Y, :Z])
        ]
      )
    ]
  )
)

expect('Deleting M should yield case 2a') {
  root.delete :M
  root
}.to_equal(
  BTree.new(
    :P,
    subtrees: [
      BTree.new(
        [:C, :G, :L],
        subtrees: [
          BTree.new([:A, :B]),
          BTree.new([:D, :E]),
          BTree.new([:J, :K]),
          BTree.new([:N, :O])
        ]
      ),
      BTree.new(
        [:T, :X],
        subtrees: [
          BTree.new([:Q, :R, :S]),
          BTree.new([:U, :V]),
          BTree.new([:Y, :Z])
        ]
      )
    ]
  )
)

expect('Deleting G should yield case 2c') {
  root.delete :G
  root
}.to_equal(
  BTree.new(
    :P,
    subtrees: [
      BTree.new(
        [:C, :L],
        subtrees: [
          BTree.new([:A, :B]),
          BTree.new([:D, :E, :J, :K]),
          BTree.new([:N, :O])
        ]
      ),
      BTree.new(
        [:T, :X],
        subtrees: [
          BTree.new([:Q, :R, :S]),
          BTree.new([:U, :V]),
          BTree.new([:Y, :Z])
        ]
      )
    ]
  )
)

expect('Deleting D should yield case 3b') {
  root.delete :D
  root
}.to_equal(
  BTree.new(
    [:C, :L, :P, :T, :X],
    subtrees: [
      BTree.new([:A, :B]),
      BTree.new([:E, :J, :K]),
      BTree.new([:N, :O]),
      BTree.new([:Q, :R, :S]),
      BTree.new([:U, :V]),
      BTree.new([:Y, :Z])
    ]
  )
)

expect('Deleting B should yield case 3a') {
  root.delete :B
  root
}.to_equal(
  BTree.new(
    [:E, :L, :P, :T, :X],
    subtrees: [
      BTree.new([:A, :C]),
      BTree.new([:J, :K]),
      BTree.new([:N, :O]),
      BTree.new([:Q, :R, :S]),
      BTree.new([:U, :V]),
      BTree.new([:Y, :Z])
    ]
  )
)

# require "minitest/autorun"
#
# describe BTree do
#   before do
#     @root = BTree.new(
#       :P,
#       subtrees: [
#         BTree.new(
#           [:C, :G, :M],
#           subtrees: [
#             BTree.new([:A, :B]),
#             BTree.new([:D, :E, :F]),
#             BTree.new([:J, :K, :L]),
#             BTree.new([:N, :O])
#           ]
#         ),
#         BTree.new(
#           [:T, :X],
#           subtrees: [
#             BTree.new([:Q, :R, :S]),
#             BTree.new([:U, :V]),
#             BTree.new([:Y, :Z])
#           ]
#         )
#       ]
#     )
#   end
#
#   describe "Deleting nodes should yield expected and valid B-trees" do
#     it "Deleting F should yield case 1" do
#       @root.delete :F
#
#       _(@root).must_equal(BTree.new(
#         :P,
#         subtrees: [
#           BTree.new(
#             [:C, :G, :M],
#             subtrees: [
#               BTree.new([:A, :B]),
#               BTree.new([:D, :E]),
#               BTree.new([:J, :K, :L]),
#               BTree.new([:N, :O])
#             ]
#           ),
#           BTree.new(
#             [:T, :X],
#             subtrees: [
#               BTree.new([:Q, :R, :S]),
#               BTree.new([:U, :V]),
#               BTree.new([:Y, :Z])
#             ]
#           )
#         ]
#       )
#     )
#     end
#   end
#
#   it "Deleting M should yield case 2a" do
#     @root.delete :M
#
#     _(@root).must_equal(
#       BTree.new(
#         :P,
#         subtrees: [
#           BTree.new(
#             [:C, :G, :L],
#             subtrees: [
#               BTree.new([:A, :B]),
#               BTree.new([:D, :E]),
#               BTree.new([:J, :K]),
#               BTree.new([:N, :O])
#             ]
#           ),
#           BTree.new(
#             [:T, :X],
#             subtrees: [
#               BTree.new([:Q, :R, :S]),
#               BTree.new([:U, :V]),
#               BTree.new([:Y, :Z])
#             ]
#           )
#         ]
#       )
#     )
#   end
# end
