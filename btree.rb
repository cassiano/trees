# brew install graphviz
# gem install ruby-graphviz

require 'ruby-graphviz'
require 'securerandom'

# https://www.geeksforgeeks.org/introduction-of-b-tree-2/
class BTree
  DEBUG = true
  ASSERTIONS = true
  T = 3   # Minimum degree.
  NODES = {
    min: T - 1,
    max: 2 * T - 1,
    middle_index: T - 1,
  }

  attr_reader :values, :subtrees, :parent

  def initialize(node_value_or_values, subtrees: nil, parent: nil)
    node_values = [*node_value_or_values]

    raise "Subtrees size (#{subtrees.size}) must match number of nodes (#{values.size}) + 1" if subtrees && subtrees.size != node_values.size + 1

    self.parent = parent
    self.values = node_values
    self.subtrees = subtrees || [nil] * (values.size + 1)
  end

  # https://www.geeksforgeeks.org/insert-operation-in-b-tree/
  def add(node_value)
    if full?
      lowest_subtree, highest_subtree, middle_value = split_child(node_value)

      target_subtree = node_value <= middle_value ? lowest_subtree : highest_subtree

      return target_subtree.add(node_value)
    end

    insertion_index = find_insertion_index(node_value)
    y = subtrees[insertion_index]

    if leaf?
      values.insert insertion_index, node_value
      subtrees.insert insertion_index, nil

      return self
    elsif y
      y.add node_value
    else
      raise "Empty node reached when adding value `#{node_value}` to non-leaf node `#{self.to_s}`."
    end
  end

  def full?
    values.size == NODES[:max]
  end

  def node_size
    values.size
  end

  def find_insertion_index(node_value)
    values.index { |v| v >= node_value } || node_size
  end

  def leaf?
    subtrees.all? &:nil?
  end

  def non_leaf?
    !leaf?
  end

  def valid?
    subtrees.size == node_size + 1 &&
      ((parent ? NODES[:min] : 1)..NODES[:max]).include?(node_size) &&
      (leaf? ? true : subtrees.all?(&:valid?))
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

  attr_writer :parent

  def subtrees=(new_subtrees)
    @subtrees = new_subtrees

    new_subtrees.each { |subtree| subtree&.parent = self }
  end

  def values=(new_values)
    raise "Minimum value not reached for subtree #{self.to_s} when setting values = `#{values.join(', ')}`" if parent && new_values.size < NODES[:min]
    raise "Maximum value exceeded for subtree #{self.to_s} when setting values = `#{values.join(', ')}`" if new_values.size > NODES[:max]

    @values = new_values
  end

  def draw_graph_tree(g, root_node)
    subtrees.each_with_index do |subtree, index|
      if subtree
        raise "Invalid parent #{parent.to_s} for sub-tree #{subtree.to_s}" if subtree.parent != self

        # https://www.graphviz.org/doc/info/shapes.html
        current_node = g.add_nodes(SecureRandom.uuid, label: subtree.values.join(', '), shape: :ellipse)

        if index < subtrees.size - 1
          edge_label = ['≼', values[index]].join
        else
          edge_label = ['≻', values[index - 1]].join
        end

        # # Draw the arrow pointing from the root node to this sub-tree.
        g.add_edges root_node, current_node, label: ' ' + edge_label

        subtree.draw_graph_tree g, current_node
      elsif !leaf?
        g.add_edges root_node, g.add_nodes(SecureRandom.uuid, shape: :point, color: :gray), arrowhead: :empty, arrowtail: :dot, color: :gray, style: :dashed
      end
    end
  end

  def split_child(node_value)
    middle_value = values[NODES[:middle_index]]
    lowest_values = values[0..(NODES[:middle_index] - 1)]
    highest_values = values[(NODES[:middle_index] + 1)..-1]

    if !parent
      # Top root node.
      lowest_subtree = self.class.new(lowest_values, subtrees: subtrees[0..NODES[:middle_index]], parent: self)
      highest_subtree = self.class.new(highest_values, subtrees: subtrees[NODES[:middle_index] + 1..-1], parent: self)

      self.values = [middle_value]
      self.subtrees = [lowest_subtree, highest_subtree]
    else
      parent_insertion_index = parent.find_insertion_index(node_value)

      # Move the middle value to its parent.
      raise "Full node `#{parent}` when trying to add value `#{middle_value}` during split." if parent.full?
      parent.values.insert parent_insertion_index, middle_value

      # Create lowest sub-tree.
      lowest_subtree = self.class.new(lowest_values, subtrees: subtrees[0..NODES[:middle_index]], parent: parent)
      parent.subtrees.insert parent_insertion_index, lowest_subtree

      highest_subtree = self

      # Update the current node to include only the highest values (and corresponding sub-trees).
      self.values = highest_values
      self.subtrees = subtrees[NODES[:middle_index] + 1..-1]
    end

    [lowest_subtree, highest_subtree, middle_value]
  end
end

@root = BTree.new(1)
(2..64).each { |value| @root.add value }
@root.as_graphviz; `open tree.png`
puts @root.valid?
