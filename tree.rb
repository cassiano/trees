# brew install graphviz
# gem install ruby-graphviz

require 'ap'
require 'ruby-graphviz'
require 'securerandom'

DEBUG = true

module TreeCaching
  def self.included(base)
    base.extend ClassMethods

    base.class_eval do
      attr_accessor :cache

      protected :cache=
    end
  end

  def initialize_cache
    self.cache = {}
  end

  def fetch_from_cache(method_name, *args, &block)
    if cache.has_key?(method_name)
      if cache[method_name].has_key?(args)
        return cache[method_name][args]
      end
    else
      cache[method_name] = {}
    end

    puts "Filling cache for method `#{method_name}` and arguments #{args} for node `#{value}`" if DEBUG

    cache[method_name][args] = block.call
  end

  module ClassMethods
    def enable_cache_for(*methods)
      methods.each do |method|
        alias_method :"original_#{method}", method

        define_method(method) do |*args|
          fetch_from_cache method, args do
            send :"original_#{method}", *args
          end
        end
      end
    end
  end
end

class Tree
  CACHING = true
  ASSERTIONS = true
  NEW_LINE = "\n"
  GUI_INDENT_SIZE = 1
  LESS_THAN = -1
  EQUAL_TO = 0
  GREATER_THAN = 1

  include TreeCaching if CACHING

  class EmptyTreeError < StandardError
  end

  attr_accessor :value
  attr_reader :left, :right, :parent

  def initialize(value, left: nil, right: nil)
    self.value = value
    self.left = left
    self.right = right

    initialize_cache if CACHING
  end

  def left=(new_left)
    # Detach the current left node, if any, from its previous parent.
    left&.parent = nil

    # Detach the new left node, if any, from its previous parent.
    new_left&.parent&.send "#{new_left.descendant_type}=", nil

    @left = new_left
    new_left&.parent = self

    clear_ancestors_caches if CACHING
  end

  def right=(new_right)
    # Detach the current right node, if any, from its previous parent.
    right&.parent = nil

    # Detach the new right node, if any, from its previous parent.
    new_right&.parent&.send "#{new_right.descendant_type}=", nil

    @right = new_right
    new_right&.parent = self

    clear_ancestors_caches if CACHING
  end

  # When cloning, notice that the receiver (i.e. self) effectively looses its children.
  def clone
    self.class.new value, left: left, right: right
  end

  # When copying attributes from another node to the receiver (i.e. self), notice that the origin node effectively looses its children.
  def copy_attrs_from(another_node)
    self.value = another_node.value
    self.left = another_node.left
    self.right = another_node.right
  end

  def leaf?
    !left && !right
  end

  def non_leaf?
    !leaf?
  end

  def orphan?
    !parent
  end

  def top_root
    parent&.top_root || self
  end

  def larger_height_child
    if (left&.height || 0) >= (right&.height || 0)
      left
    else
      right
    end
  end

  def descendant_type
    [:left, :right].find { |type| parent.send(type) == self } if parent
  end

  def height
    1 + [left&.height || 0, right&.height || 0].max
  end

  def count
    1 + (left&.count || 0) + (right&.count || 0)
  end

  def leaves
    leaf? ?
      [self] :
      (left&.leaves || []) + (right&.leaves || [])
  end

  def non_leaves
    leaf? ?
      [] :
      [self] + (left&.non_leaves || []) + (right&.non_leaves || [])
  end

  def pre_order
    [self] + (left&.pre_order || []) + (right&.pre_order || [])
  end

  def in_order
    (left&.in_order || []) + [self] + (right&.in_order || [])
  end

  def post_order
    (left&.post_order || []) + (right&.post_order || []) + [self]
  end

  def leftmost_node
    left&.leftmost_node || self
  end

  def rightmost_node
    right&.rightmost_node || self
  end

  def ancestors
    [self].tap do |ancestors_path|
      ancestors_path.concat parent.ancestors if parent
    end
  end

  def deepest_path
    [self] + (larger_height_child&.deepest_path || [])
  end

  def fill_factor
    count.to_f / (2 ** height - 1)
  end

  def max
    [left&.max, value, right&.max].compact.max
  end

  def min
    [left&.min, value, right&.min].compact.min
  end

  # Find path with maximum sum: `@root.find_min_max_reduced_path(:max, &:+).map(&:value)`
  # Find path with minimum sum: `@root.find_min_max_reduced_path(:min, &:+).map(&:value)`
  # Find path with maximum sum of last digit, only for even numbers: `@root.find_min_max_reduced_path(:max) { |memo, i| v = i % 10; memo + (v.even? ? v : 0) }.map(&:value)`
  def find_min_max_reduced_path(min_or_max, &block)
    raise "Please specify either :min or :max as the 1st parameter" unless [:min, :max].include?(min_or_max)

    left_path = left&.find_min_max_reduced_path(min_or_max, &block) || []
    right_path = right&.find_min_max_reduced_path(min_or_max, &block) || []

    left_reduction = left_path.map(&:value).reduce(0, &block)
    right_reduction = right_path.map(&:value).reduce(0, &block)

    [self] + (left_reduction.send(min_or_max == :min ? :<= : :>=, right_reduction) ? left_path : right_path)
  end

  def as_text
    { ✉: value }.tap do |result|
      result.merge! ⬋: left.as_text if left
      result.merge! ⬊: right.as_text if right
    end
  end

  def as_gui(prefix = '')
    ''.tap do |output|
      output << [prefix, value, NEW_LINE].join
      output << [prefix, '├─ ⬋: ', NEW_LINE, left.as_gui(prefix + '│' + '  ' * GUI_INDENT_SIZE)].join if left
      output << [prefix, '├─ ⬊', (left ? [' (', value, ')'].join : ''), ': ', NEW_LINE, right.as_gui(prefix + '│' + '  ' * GUI_INDENT_SIZE)].join if right
    end
  end

  #                                                                             24
  #                                      ┌──────────────────────────────────────┴──────────────────────────────────────┐
  #                                      10                                                                            47
  #                  ┌───────────────────┴──────────────────┐                                      ┌───────────────────┴───────────────────┐
  #                  6                                      17                                     37                                      55
  #        ┌─────────┴─────────┐                  ┌─────────┴─────────┐                  ┌─────────┴─────────┐                   ┌─────────┴─────────┐
  #        3                   8                  14                  20                 31                  42                  50                  60
  #   ┌────┴────┐         ┌────┴────┐        ┌────┴────┐         ┌────┴────┐        ┌────┴────┐         ┌────┴────┐         ┌────┴────┐         ┌────┴────┐
  #   2         4         7         9        12        15        19        22       27        33        39        45        49        53        57        62
  # ┌─┘         └─┐                        ┌─┴─┐       └─┐    ┌──┘      ┌──┴─┐    ┌─┴─┐    ┌──┴─┐    ┌──┴─┐    ┌──┴─┐    ┌──┘      ┌──┴─┐    ┌──┴─┐    ┌──┴─┐
  # 1             5                        11  13        16   18        21   23   26  29   32   35   38   41   44   46   48        51   54   56   58   61   63
  def as_tree_gui(width:)
    return "Tree is too high and cannot be drawn!" if (tree_height = height) > Math.log(width, 2).to_int

    (tree_height * 2 - 1).times.inject([]) { |memo, _| memo << [' ' * width, NEW_LINE].join }.tap do |canvas|
      inner_as_tree_gui canvas, 0..(width - 1), 1
    end
  end

  def as_graphviz(image_file = 'tree.png')
    g = GraphViz.new(:G, type: :digraph)

    draw_graph_tree g, g.add_nodes(SecureRandom.uuid, label: value.to_s, shape: leaf? ? :doublecircle : :circle)

    g.output png: image_file
  end

  def clear_descendants_caches
    pre_order.each &:clear_cache
  end

  def clear_cache
    puts "Clearing cache for node `#{value}`" if DEBUG

    initialize_cache
  end

  def to_s
    { value: value, parent: parent&.value, left: left&.value, right: right&.value }
  end

  alias_method :inspect, :to_s

  protected

  attr_writer :parent

  def clear_ancestors_caches
    ancestors.each &:clear_cache
  end

  def inner_as_tree_gui(canvas, range, level, type = nil)
    canvas.tap do
      canvas_row = 2 * (level - 1)
      mean_position = mean(range.begin, range.end)
      left_position = mean(range.begin, mean_position)
      right_position = mean(mean_position, range.end)   # Unused.
      offspring_line_width = (range.end - range.begin + 1) / 4
      parent_node_connection_char =
        if left && right
          '┴'
        elsif left
          '┘'
        elsif right
          '└'
        end

      fill_canvas canvas, canvas_row, value.to_s, mean_position

      if left || right
        # Draw lines connecting the current node to existing sub-trees.
        fill_canvas(canvas, canvas_row + 1, '┌' + '─' * offspring_line_width, left_position) if left
        fill_canvas(canvas, canvas_row + 1, parent_node_connection_char, mean_position)
        fill_canvas(canvas, canvas_row + 1, '─' * (offspring_line_width - 1) + '┐', mean_position + 1) if right
      end

      left&.inner_as_tree_gui canvas, range.begin..mean_position, level + 1, :left
      right&.inner_as_tree_gui canvas, mean_position..range.end, level + 1, :right
    end
  end

  def draw_graph_tree(g, root_node)
    [left, right].each do |sub_tree|
      if sub_tree
        # https://www.graphviz.org/doc/info/shapes.html
        current_node = g.add_nodes(SecureRandom.uuid, label: sub_tree.value.to_s, shape: sub_tree.leaf? ? :doublecircle : :circle)

        # # Draw the arrow pointing from the root node to this sub-tree.
        g.add_edges root_node, current_node, label: [' ', sub_tree == left ? '≼' : '≻', ' ', value].join

        sub_tree.draw_graph_tree g, current_node
      elsif !leaf?
        g.add_edges root_node, g.add_nodes(SecureRandom.uuid, shape: :point, color: :gray), arrowhead: :empty, arrowtail: :dot, color: :gray, style: :dashed
      end
    end
  end

  private

  def mean(a, b)
    (a + b) / 2
  end

  def fill_canvas(canvas, row, text, position)
    raise "Cannot fill canvas with text `#{text}` at position #{position} in row #{row}" if position < 0 || position + text.size > canvas[row].size

    canvas[row][position..position + text.size - 1] = text
  end

  # PS: only cache methodswhich are R/O (i.e. that do not update the tree in any way) and depend exclusively on the current node and/or its descendants, never on its ancestors.
  if CACHING
    enable_cache_for :larger_height_child, :height, :count, :leaves, :non_leaves, :pre_order, :in_order, :post_order, :leftmost_node, :rightmost_node, :deepest_path, :fill_factor,
                     :max, :min, :as_text, :as_gui, :as_tree_gui, :as_graphviz
  end
end

class BST < Tree
  attr_accessor :comparison_block

  def initialize(*args, &comparison_block)
    super

    @comparison_block = comparison_block
  end

  def add(node_value)
    raise "Please supply a non-null node value." if node_value.nil?
    raise "Incompatible type `#{node_value.class}` being added." unless value <=> node_value && node_value <=> value

    begin
      case compare(node_value, value)
        when LESS_THAN, EQUAL_TO
          if left
            left.add node_value
          else
            self.class.new(node_value, &comparison_block).tap do |new_child|
              self.left = new_child
            end
          end
        when GREATER_THAN
          if right
            right.add node_value
          else
            self.class.new(node_value, &comparison_block).tap do |new_child|
              self.right = new_child
            end
          end
      end
    ensure
      clear_ancestors_caches if CACHING
    end
  end

  # https://www.geeksforgeeks.org/binary-find-tree-set-2-delete/
  def delete(node_or_value)
    return unless (node = node_or_value.is_a?(self.class) ? node_or_value : find(node_or_value))

    begin
      node_parent = node.parent

      # Has both children?
      if node.left && node.right
        # Find the node's inorder successor (its right child's leftmost node). PS: using the inorder predecessor would also work.
        leftmost = node.right.leftmost_node

        # Replace the node to be deleted's value by the right child's leftmost node value.
        node.value = leftmost.value
        delete leftmost

        # Alternative:
        #
        # rightmost.parent.send "#{rightmost.descendant_type}=", rightmost.left
        # node.value = rightmost.value
      else
        # Has at least 1 child?
        if (child = node.left || node.right)
          node.copy_attrs_from child    # Copy the (single) child attributes to it.
        elsif !node.orphan?   # Leaf node. Node has a parent?
          node.parent.send "#{node.descendant_type}=", nil    # Leaf node which is not the main root. Simply nullify its parent left or right subtree.
        else    # Main (and leaf) root.
          raise EmptyTreeError
        end
      end
    ensure
      node_parent&.clear_ancestors_caches if CACHING
    end
  end

  def find(node_value)
    case compare(node_value, value)
      when EQUAL_TO
        self
      when LESS_THAN
        left&.find node_value
      when GREATER_THAN
        right&.find node_value
    end
  end

  def max
    rightmost_node&.value
  end

  def min
    leftmost_node&.value
  end

  def clone
    super.tap do |cloned_object|
      cloned_object.comparison_block = comparison_block
    end
  end

  protected :left=, :right=, :value=, :comparison_block=

  protected

  def compare(a, b)
    comparison_block ? comparison_block.call(a, b) : a <=> b
  end

  # PS: only cache methods which are R/O (i.e. that do not update the tree in any way) and depend exclusively on the current node and/or its descendants, never on its ancestors.
  enable_cache_for :find, :max, :min if CACHING
end

class AvlTree < BST
  attr_accessor :ancestors_checked_after_insertion

  def add(node_value)
    puts "Adding #{node_value} to sub-tree #{value}" if DEBUG

    super.tap do |new_child|
      new_child.rebalance_after_insertion

      if ASSERTIONS
        raise "Tree became unbalanced after adding node #{node_value}!" unless top_root.balanced?
      end
    end
  end

  # https://www.geeksforgeeks.org/avl-tree-set-2-deletion/
  def delete(node_or_value)
    puts "Deleting #{node_or_value} from sub-tree #{value}" if DEBUG

    return unless (node = node_or_value.is_a?(self.class) ? node_or_value : find(node_or_value))

    node_parent = node.parent

    super

    if node_parent
      node_parent.ancestors.each do |node_to_be_checked|
        node_to_be_checked.rebalance_after_deletion
      end
    end

    # Check the reason for the message: `NoMethodError (protected method `rebalance_after_deletion' called for #<AvlTree:0x00007f8c079626a8>)`
    # node_parent.ancestors.each(&:rebalance_after_deletion) if node_parent

    if ASSERTIONS
      raise "Tree became unbalanced after deleting node #{node.value}!" unless top_root.balanced?
    end
  end

  # An AVL tree is considered balanced when differences between heights of left and right subtrees for every node is less than or equal to 1.
  def balanced?
    balance_factor <= 1 && (left ? left.balanced? : true) && (right ? right.balanced? : true)   # Do not use `left&.balanced? || true`.
  end

  protected

  # T1, T2 and T3 are subtrees of the tree rooted with y (on the left side) or x (on the right side).
  #
  #      y      Right Rotation       x
  #     / \        ------->         / \
  #    x  T3                      T1  y
  #   / \          <-------          / \
  # T1  T2      Left Rotation      T2  T3
  #
  # Source: https://www.geeksforgeeks.org/avl-tree-set-1-insertion/
  def rotate(direction)
    puts "Rotating node #{value} to the #{direction}..." if DEBUG

    previous_parent = parent

    case direction
      when :left
        x = self                  # Current root.
        y = x.right
        x_clone = x.clone
        t2 = y.left
        x_clone.right = t2
        y.left = x_clone
        x.copy_attrs_from y       # Original x get all y's data (value + left/right subtrees), in practice making y the new root.
      when :right
        raise "Invalid condition found for right rotation. Current node (#{value}) must be necessarily greater than left node (#{left.value})" if compare(value, left.value) != 1

        y = self                  # Current root.
        x = y.left
        y_clone = y.clone
        t2 = x.right
        y_clone.left = t2
        x.right = y_clone
        y.copy_attrs_from x       # Original y get all x's data (value + left/right subtrees), in practice making x the new root.
    end
  end

  def unbalanced_ancestors_path
    all_ancestors = ancestors

    first_unbalanced_ancestor = all_ancestors.index { |node| !node.balanced? }

    [!!first_unbalanced_ancestor, all_ancestors[0..first_unbalanced_ancestor]]
  end

  def rebalance_after_insertion
    unless ancestors_checked_after_insertion
      puts "Rebalancing node #{value} after insert operation" if DEBUG

      found_unbalanced_node, ancestors_path = unbalanced_ancestors_path

      if found_unbalanced_node
        if ancestors_path.size >= 3
          z = ancestors_path[-1]
          y = ancestors_path[-2]
          x = ancestors_path[-3]

          puts "Unbalanced node found with value #{z.value}" if DEBUG

          case [y.descendant_type, x.descendant_type]
            when [:left, :left]
              z.rotate :right
            when [:left, :right]
              y.rotate :left
              z.rotate :right
            when [:right, :right]
              z.rotate :left
            when [:right, :left]
              y.rotate :right
              z.rotate :left
          end
        else
          raise "Unbalanced node found with value #{ancestors_path[-1].value}, but ancestors path size is < 3 (#{ancestors_path.size})"
        end
      else
        puts "No unbalanced nodes found!" if DEBUG
      end

      self.ancestors_checked_after_insertion = true
    end
  end

  def rebalance_after_deletion
    return if balanced?

    puts "Rebalancing node #{value} after delete operation" if DEBUG

    found_unbalanced_node, ancestors_path = unbalanced_ancestors_path

    if found_unbalanced_node
      z = ancestors_path[-1]

      puts "Unbalanced node found with value #{z.value}" if DEBUG

      if z.height >= 3
        y = z.larger_height_child
        x = y.larger_height_child

        case [y.descendant_type, x.descendant_type]
          when [:left, :left]
            z.rotate :right
          when [:left, :right]
            y.rotate :left
            y.rebalance_after_deletion
            z.rotate :right
          when [:right, :right]
            z.rotate :left
          when [:right, :left]
            y.rotate :right
            y.rebalance_after_deletion
            z.rotate :left
        end

        z.rebalance_after_deletion
      else
        raise "Unbalanced node found with value #{ancestors_path[-1].value}, but its height < 3 (#{z.height})"
      end
    else
      puts "No unbalanced nodes found!" if DEBUG
    end
  end

  private

  def balance_factor
    ((left&.height || 0) - (right&.height || 0)).abs
  end

  # PS: only cache methods which are R/O (i.e. that do not update the tree in any way) and depend exclusively on the current node and/or its descendants, never on its ancestors.
  enable_cache_for :balanced?, :balance_factor if CACHING
end

# root = Tree.new(:a, left: Tree.new(:b), right: Tree.new(:c, left: Tree.new(:d)))

# def reorder_by_collecting_middle_element(items)
#   return items if items.size <= 2
#
#   middle_index = items.size / 2
#
#   ([items[middle_index]] + reorder_by_collecting_middle_element(items[0..middle_index-1]) + reorder_by_collecting_middle_element(items[middle_index+1..-1]))
# end

# items = reorder_by_collecting_middle_element((1..(2**6 - 1)).to_a)
items = (1..(2 ** 6 - 1)).to_a.shuffle

p items

@root = AvlTree.new(items.shift)

items.each_with_index do |item, i|
  puts i if i % 1000 == 0

  @root.add item
end

ap @root.as_text
puts
puts @root.as_gui
puts
puts @root.as_tree_gui(width: 158)
puts
puts "Tree fill factor: #{"%3.3f" % (@root.fill_factor * 100)} %"
puts "Height: #{@root.height}"
puts
p @root.in_order.map(&:value)
@root.as_graphviz; `open tree.png`

# loop { node = @root.in_order.sample; puts "Deleting #{node.value}"; @root.delete node; puts @root.as_tree_gui(width: 158); break if @root.count == 1 }
# puts "Deleting and adding nodes..."
# 100_000.times { |i| puts i if i % 1000 == 0; node = @root; @root.delete node; value = rand(10**30); next if @root.find(value); @root.add value }; puts @root.balanced?

