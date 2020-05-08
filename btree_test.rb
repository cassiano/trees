require './btree.rb'
require './test_spec.rb'

puts "===== Testing add() method ====="

root = BTree.new

expect("BTree's minimum degree should be 3 for all tests") { BTree::T }.to_equal(3)

expect('Adding 10, 20, 30, 40, 50 should be done in a single node (top root)') {
  root.tap { [10, 20, 30, 40, 50].each { |key| root.add key } }
}
  .to_be_true(:valid?)
  .to_equal(
    BTree.new([10, 20, 30, 40, 50])
  )

expect('Adding 60 should split the root node') {
  root.tap { root.add 60 }
}.to_equal(
  BTree.new(
    30,
    subtrees: [
      BTree.new([10, 20]),
      BTree.new([40, 50, 60])
    ]
  )
)

expect('Adding 70, 80 should be done in the right child node') {
  root.tap { [70, 80].each { |key| root.add key } }
}.to_equal(
  BTree.new(
    30,
    subtrees: [
      BTree.new([10, 20]),
      BTree.new([40, 50, 60, 70, 80])
    ]
  )
)

expect('Adding 90 should split the right child node') {
  root.tap { root.add 90 }
}.to_equal(
  BTree.new(
    [30, 60],
    subtrees: [
      BTree.new([10, 20]),
      BTree.new([40, 50]),
      BTree.new([70, 80, 90])
    ]
  )
)

puts "===== Testing delete() method ====="

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
  root.tap { root.delete :F }
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
  root.tap { root.delete :M }
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
  root.tap { root.delete :G }
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
  root.tap { root.delete :D }
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
  root.tap { root.delete :B }
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

expect('Deleting P should yield case 2b') {
  root.tap { root.delete :P }
}.to_equal(
  BTree.new(
    [:E, :L, :Q, :T, :X],
    subtrees: [
      BTree.new([:A, :C]),
      BTree.new([:J, :K]),
      BTree.new([:N, :O]),
      BTree.new([:R, :S]),
      BTree.new([:U, :V]),
      BTree.new([:Y, :Z])
    ]
  )
)

# require "minitest/autorun"
#
# class TestMeme < MiniTest::Unit::TestCase
#   def test_that_delete_works_as_expected
#     root = BTree.new(
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
#     assert root.valid?
#
#     assert_equal(
#       BTree.new(
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
#       ),
#       root.tap { root.delete :F }
#     )
#     assert root.valid?
#
#     assert_equal(
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
#       ),
#       root.tap { root.delete :M }
#     )
#     assert root.valid?
#   end
#
#   def test_that_add_works_as_expected
#     root = BTree.new(10)
#
#     assert_equal(
#       BTree.new([10, 20, 30, 40, 50]),
#       root.tap { [20, 30, 40, 50].each { |key| root.add key } }
#     )
#     assert root.valid?
#   end
# end
