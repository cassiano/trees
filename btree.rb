# brew install graphviz
# gem install ruby-graphviz

require 'ruby-graphviz'
require 'securerandom'

DEBUG = true

# https://www.geeksforgeeks.org/introduction-of-b-tree-2/
class BTree
  T = 3   # Minimum degree.
  NODES = {
    min: T - 1,
    max: 2 * T - 1,
    middle_index: T - 1,
  }

  attr_accessor :values, :subtrees, :parent

  def initialize(node_value_or_values, subtrees: nil, parent: nil)
    node_values = [*node_value_or_values]

    if node_values.size > NODES[:max]
      raise "Exceeded maximum node size (#{NODES[:max]}) when creating new B-tree with initial values `#{node_values}` and parent `#{parent}`."
    elsif node_values.size < NODES[:min] && parent
      raise "Minimum node size (#{NODES[:min]}) not reached when creating new (non-top root) B-tree with initial values `#{node_values}` and parent `#{parent}`."
    end

    raise "Subtrees size (#{subtrees.size}) must match number of nodes (values.size) + 1" if subtrees && subtrees.size != node_values.size + 1

    @values = node_values
    @subtrees = subtrees || [nil] * (values.size + 1)
    @parent = parent
  end

  # https://www.geeksforgeeks.org/insert-operation-in-b-tree/
  def add(node_value)
    # x = self
    insertion_index = values.index { |v| v >= node_value } || node_size
    y = subtrees[insertion_index]

    if leaf?
      if !full?
        values.insert insertion_index, node_value
        subtrees.insert insertion_index, nil
      else
        # Split it.
        if !parent
          # Top root node.
          _, _, middle_value = split_child(insertion_index)

          subtrees[node_value <= middle_value ? 0 : 1].add node_value
        else
          raise "Leaf and full (non-top root) node `#{self}` reached when adding `#{node_value}`."
        end
      end
    elsif y
      if full?
        lowest_subtree, highest_subtree, middle_value = split_child(insertion_index)

        if node_value <= middle_value
          y = lowest_subtree
          insertion_index = 0
        else
          y = highest_subtree
          insertion_index = 1
        end
      end

      if y.full?
        lowest_subtree, highest_subtree, middle_value = y.split_child(insertion_index)

        (node_value <= middle_value ? lowest_subtree : highest_subtree).add node_value
      else
        y.add node_value
      end
    else
      raise "Empty node reached when adding value `#{node_value}` to non-leaf node `#{self}`."
    end
  end

  def full?
    values.size == NODES[:max]
  end

  def node_size
    values.size
  end

  def leaf?
    subtrees.all? &:nil?
  end

  def non_leaf?
    !leaf?
  end

  def to_s
    { values: values, subtrees: subtrees.map(&:to_s) }
  end

  alias_method :inspect, :to_s

  def as_graphviz(image_file = 'tree.png')
    g = GraphViz.new(:G, type: :digraph)

    draw_graph_tree g, g.add_nodes(SecureRandom.uuid, label: values.join(', '), shape: :ellipse)

    g.output png: image_file
  end

  protected

  def draw_graph_tree(g, root_node)
    subtrees.each do |sub_tree|
      if sub_tree
        # https://www.graphviz.org/doc/info/shapes.html
        current_node = g.add_nodes(SecureRandom.uuid, label: sub_tree.values.join(', '), shape: :ellipse)

        # # Draw the arrow pointing from the root node to this sub-tree.
        # g.add_edges root_node, current_node, label: [' ', sub_tree == left ? '≼' : '≻', ' ', value].join
        g.add_edges root_node, current_node

        sub_tree.draw_graph_tree g, current_node
      elsif !leaf?
        g.add_edges root_node, g.add_nodes(SecureRandom.uuid, shape: :point, color: :gray), arrowhead: :empty, arrowtail: :dot, color: :gray, style: :dashed
      end
    end
  end

  def split_child(insertion_index)
    middle_value = values[NODES[:middle_index]]
    lowest_values = values[0..(NODES[:middle_index] - 1)]
    highest_values = values[(NODES[:middle_index] + 1)..-1]

    if !parent
      # Top root node.
      self.values = [middle_value]

      lowest_subtree = self.class.new(lowest_values, parent: self)
      highest_subtree = self.class.new(highest_values, parent: self)

      self.subtrees = [lowest_subtree, highest_subtree]
    else
      # Move the middle value to its parent.
      raise "Full node `#{parent}` when trying to add value `#{middle_value}` during split." if parent.full?
      parent.values.insert insertion_index, middle_value

      # Create lowest sub-tree.
      lowest_subtree = self.class.new(lowest_values, subtrees: subtrees[0..NODES[:middle_index]], parent: parent)
      highest_subtree = self
      parent.subtrees.insert insertion_index, lowest_subtree

      # Update the current node to include only the highest values (and corresponding sub-trees).
      self.values = highest_values
      self.subtrees = subtrees[NODES[:middle_index] + 1..-1]
    end

    [lowest_subtree, highest_subtree, middle_value]
  end
end

@root = BTree.new(1)
(2..19).each { |value| @root.add value }
@root.as_graphviz; `open tree.png`
