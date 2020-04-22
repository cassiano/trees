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

    self.parent = parent
    self.values = node_values
    self.subtrees = subtrees || [nil] * (values.size + 1)
  end

  # https://www.geeksforgeeks.org/insert-operation-in-b-tree/
  def add(node_value)
    if full?
      minors_subtree, majors_subtree, middle_value = split_child(node_value)

      target_subtree = node_value <= middle_value ? minors_subtree : majors_subtree

      target_subtree.add node_value
    else
      insertion_index = find_subtree_index(node_value)
      y = subtrees[insertion_index]

      if leaf?
        insert_value node_value, insertion_index
        insert_subtree nil, insertion_index

        self
      elsif y
        y.add node_value
      else
        raise "Empty node reached when adding value `#{node_value}` to non-leaf node #{self}."
      end
    end
  end

  def full?
    values.size == NODES[:max]
  end

  def nodes_count
    values.size
  end

  def subtrees_count
    subtrees.size
  end

  def find_subtree_index(node_value)
    values.index { |v| v >= node_value } || nodes_count
  end

  def find_subtree(node_value)
    subtrees[find_subtree_index(node_value)]
  end

  def leaf?
    subtrees.all? &:nil?
  end

  def non_leaf?
    !leaf?
  end

  def valid?
    subtrees_count == nodes_count + 1 &&
      within_size_limits? &&
      (leaf? ? true : subtrees.all?(&:valid?))
  end

  def total_nodes_count
    nodes_count + (leaf? ? 0 : subtrees.map(&:total_nodes_count).reduce(:+))
  end

  def total_nodes
    1 + (leaf? ? 0 : subtrees.map(&:total_nodes).reduce(:+))
  end

  def average_nodes_count
    total_nodes_count.to_f / total_nodes
  end

  def find(node_value)
    if values.index(node_value)
      self
    elsif non_leaf?
      find_subtree(node_value).find node_value
    end
  end

  # https://stackoverflow.com/questions/25488902/what-happens-when-you-use-string-interpolation-in-ruby
  def to_s
    { values: values, subtrees: subtrees.map(&:to_s) }.to_s
  end

  alias_method :inspect, :to_s

  def as_graphviz(image_file = 'tree.png')
    g = GraphViz.new(:G, type: :digraph)

    draw_graph_tree g, g.add_nodes(SecureRandom.uuid, label: values.join(', '), shape: :ellipse)

    g.output png: image_file
  end

  protected

  attr_writer :parent

  def within_size_limits?
    ((parent ? NODES[:min] : 1)..NODES[:max]).include? nodes_count
  end

  def insert_value(node_value, position)
    raise "Maximum node size exceeded for subtree #{self} when inserting value `#{node_value}`." if nodes_count + 1 > NODES[:max]

    values.insert position, node_value
  end

  def insert_subtree(subtree, position)
    subtrees.insert position, subtree
  end

  def subtrees=(new_subtrees)
    raise "Subtrees size (#{new_subtrees.size}) must match number of nodes (#{nodes_count}) + 1." if new_subtrees.size != nodes_count + 1

    @subtrees = new_subtrees

    new_subtrees.each { |subtree| subtree&.parent = self }
  end

  def values=(new_values)
    raise "Minimum node size not reached for subtree #{self} when setting values `#{values.join(', ')}`." if parent && new_values.size < NODES[:min]
    raise "Maximum node size exceeded for subtree #{self} when setting values `#{values.join(', ')}`." if new_values.size > NODES[:max]

    @values = new_values
  end

  def draw_graph_tree(g, root_node)
    subtrees.each_with_index do |subtree, index|
      if subtree
        raise "Invalid parent #{parent} for sub-tree #{subtree}." if subtree.parent != self

        # https://www.graphviz.org/doc/info/shapes.html
        current_node = g.add_nodes(SecureRandom.uuid, label: subtree.values.join(', '), shape: :ellipse)

        if index == 0
          edge_label = ['≼', values[index]].join
        elsif index == subtrees_count - 1
          edge_label = ['≻', values[index - 1]].join
        else
          edge_label = [' ', values[index - 1], '...', values[index]].join
        end

        # # Draw the arrow pointing from the root node to this sub-tree.
        g.add_edges root_node, current_node, label: edge_label

        subtree.draw_graph_tree g, current_node
      elsif !leaf?
        g.add_edges root_node, g.add_nodes(SecureRandom.uuid, shape: :point, color: :gray), arrowhead: :empty, arrowtail: :dot, color: :gray, style: :dashed
      end
    end
  end

  def split_child(node_value)
    splitted = split_node_in_middle
    splitted_values = splitted[:values]
    splitted_subtrees = splitted[:subtrees]

    # Top root node?
    if parent
      # No.
      parent_insertion_index = parent.find_subtree_index(node_value)

      # Move the middle value to its parent.
      raise "Full node #{parent} when trying to add value `#{splitted[:middle_value]}` during split." if parent.full?
      parent.insert_value splitted[:middle_value], parent_insertion_index

      # Create minors sub-tree.
      minors_subtree = self.class.new(splitted_values[:minors], subtrees: splitted_subtrees[:minors], parent: parent)
      parent.insert_subtree minors_subtree, parent_insertion_index

      majors_subtree = self

      # Update the current node to include only the majors' values (and corresponding sub-trees).
      self.values = splitted_values[:majors]
      self.subtrees = splitted_subtrees[:majors]
    else
      # Yes.
      minors_subtree = self.class.new(splitted_values[:minors], subtrees: splitted_subtrees[:minors], parent: self)
      majors_subtree = self.class.new(splitted_values[:majors], subtrees: splitted_subtrees[:majors], parent: self)

      self.values = [splitted[:middle_value]]
      self.subtrees = [minors_subtree, majors_subtree]
    end

    [minors_subtree, majors_subtree, splitted[:middle_value]]
  end

  def split_node_in_middle
    {
      middle_value: values[NODES[:middle_index]],
      values: {
        minors: values[0..(NODES[:middle_index] - 1)],
        majors: values[(NODES[:middle_index] + 1)..-1],
      },
      subtrees: {
        minors: subtrees[0..NODES[:middle_index]],
        majors: subtrees[NODES[:middle_index] + 1..-1],
      }
    }
  end
end

@root = BTree.new(1)
(2..2**6).each_with_index { |value, i| puts i if i % 1000 == 0; @root.add value }
@root.as_graphviz; `open tree.png`
puts @root.valid?
puts "Tree average node size: #{"%3.1f" % (@root.average_nodes_count)}"
