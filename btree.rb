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
  ELLIPSIS = '…'

  attr_reader :keys, :subtrees, :parent

  def initialize(key_or_keys, subtrees: nil, parent: nil)
    keys = [*key_or_keys]

    self.parent = parent
    self.keys = keys
    self.subtrees = subtrees || [nil] * (keys.size + 1)
  end

  # https://www.geeksforgeeks.org/insert-operation-in-b-tree/
  def add(key)
    if full?
      minors_subtree, majors_subtree, middle_key = split_child(key)

      target_subtree = key <= middle_key ? minors_subtree : majors_subtree

      target_subtree.add key
    else
      insertion_index = find_subtree_index(key)
      y = subtrees[insertion_index]

      if leaf?
        insert_key key, insertion_index
        insert_subtree nil, insertion_index

        self
      elsif y
        y.add key
      else
        raise "Empty node reached when adding key `#{key}` to non-leaf node #{self}."
      end
    end
  end

  def full?
    keys.size == NODES[:max]
  end

  def keys_count
    keys.size
  end

  def subtrees_count
    subtrees.size
  end

  def leaf?
    subtrees.all? &:nil?
  end

  def non_leaf?
    !leaf?
  end

  def valid?
    subtrees_count == keys_count + 1 &&
      within_size_limits? &&
      (tree_height = height) && subtrees.all? { |subtree| (subtree&.height || 0) == tree_height - 1 } &&
      (leaf? ? true : subtrees.all?(&:valid?))
  end

  def total_keys_count
    keys_count + (leaf? ? 0 : subtrees.map(&:total_keys_count).reduce(:+))
  end

  def total_nodes_count
    1 + (leaf? ? 0 : subtrees.map(&:total_nodes_count).reduce(:+))
  end

  def average_keys_count
    total_keys_count.to_f / total_nodes_count
  end

  def find(key)
    subtree_index = find_subtree_index(key)

    if subtree_index < keys_count && keys[subtree_index] == key
      self
    elsif non_leaf?
      subtrees[subtree_index].find key
    end
  end

  def descendant_index
    parent&.find_subtree_index keys[0]    # The key is not relevant. We could have picked any of the current node.
  end

  def height
    (subtrees[0]&.height || 0) + 1
  end

  # def pre_order
  #   non_leaf? ?
  #     subtrees.each_with_index.reduce([]) do |memo, (subtree, i)|
  #       memo + (i < keys_count ? [keys[i]] : []) + subtree.pre_order
  #     end :
  #     keys
  # end

  def in_order
    non_leaf? ?
      subtrees.each_with_index.reduce([]) do |memo, (subtree, i)|
        memo + subtree.in_order + (i < keys_count ? [keys[i]] : [])
      end :
      keys
  end

  # def post_order
  #   non_leaf? ?
  #     subtrees.each_with_index.reduce([]) do |memo, (subtree, i)|
  #       memo + subtree.post_order + (i < keys_count ? [keys[i]] : [])
  #     end :
  #     keys
  # end

  # https://stackoverflow.com/questions/25488902/what-happens-when-you-use-string-interpolation-in-ruby
  def to_s
    { keys: keys, subtrees: subtrees.map(&:to_s) }.to_s
  end

  alias_method :inspect, :to_s

  def as_graphviz(image_file = 'tree.png')
    g = GraphViz.new(:G, type: :digraph)

    draw_graph_tree g, g.add_node(SecureRandom.uuid, label: keys.join(', '), shape: :ellipse)

    g.output png: image_file
  end

  protected

  attr_writer :parent

  def find_subtree_index(key)
    keys.index { |v| key <= v } || keys_count
  end

  def find_subtree(key)
    subtrees[find_subtree_index(key)]
  end

  def within_size_limits?
    ((parent ? NODES[:min] : 1)..NODES[:max]).include? keys_count
  end

  def insert_key(key, position)
    raise "Maximum node size exceeded for subtree #{self} when inserting key `#{key}`." if keys_count + 1 > NODES[:max]

    keys.insert position, key
  end

  def insert_subtree(subtree, position)
    subtrees.insert position, subtree
  end

  def subtrees=(new_subtrees)
    raise "Subtrees size (#{new_subtrees.size}) must match number of keys (#{keys_count}) + 1." if new_subtrees.size != keys_count + 1

    @subtrees = new_subtrees

    new_subtrees.each { |subtree| subtree&.parent = self }
  end

  def keys=(new_keys)
    raise "Minimum node size not reached for subtree #{self} when setting keys `#{keys.join(', ')}`." if parent && new_keys.size < NODES[:min]
    raise "Maximum node size exceeded for subtree #{self} when setting keys `#{keys.join(', ')}`." if new_keys.size > NODES[:max]

    @keys = new_keys
  end

  def draw_graph_tree(g, root_key)
    subtrees.each_with_index do |subtree, index|
      if subtree
        raise "Invalid parent #{parent} for sub-tree #{subtree}." if subtree.parent != self

        # https://www.graphviz.org/doc/info/shapes.html
        current_key = g.add_node(SecureRandom.uuid, label: subtree.keys.join(', '), shape: :ellipse)

        edge_label = if index == 0
          if (ancestor_key = find_first_ancestor_key_with_non_minimum_descendant_index)
            [ancestor_key, ELLIPSIS, keys[index]].join
          else
            [ELLIPSIS, keys[index]].join
          end
        elsif index == subtrees_count - 1
          if (ancestor_key = find_first_ancestor_key_with_non_maximum_descendant_index)
            [keys[index - 1], ELLIPSIS, ancestor_key].join
          else
            [keys[index - 1], ELLIPSIS].join
          end
        else
          [keys[index - 1], ELLIPSIS, keys[index]].join
        end

        # # Draw the arrow pointing from the root key to this sub-tree.
        g.add_edges root_key, current_key, label: edge_label

        subtree.draw_graph_tree g, current_key
      elsif !leaf?
        g.add_edges root_key, g.add_keys(SecureRandom.uuid, shape: :point, color: :gray), arrowhead: :empty, arrowtail: :dot, color: :gray, style: :dashed
      end
    end
  end

  private

  def split_child(key)
    splitted = split_key_in_middle
    splitted_keys = splitted[:keys]
    splitted_subtrees = splitted[:subtrees]

    # Top root key?
    if parent
      # No.
      parent_insertion_index = parent.find_subtree_index(key)

      # Move the middle key to its parent.
      raise "Full node #{parent} when trying to add key `#{splitted[:middle_key]}` during split." if parent.full?
      parent.insert_key splitted[:middle_key], parent_insertion_index

      # Create minors sub-tree.
      minors_subtree = self.class.new(splitted_keys[:minors], subtrees: splitted_subtrees[:minors], parent: parent)
      parent.insert_subtree minors_subtree, parent_insertion_index

      majors_subtree = self

      # Update the current key to include only the majors' keys (and corresponding sub-trees).
      self.keys = splitted_keys[:majors]
      self.subtrees = splitted_subtrees[:majors]
    else
      # Yes.
      minors_subtree = self.class.new(splitted_keys[:minors], subtrees: splitted_subtrees[:minors], parent: self)
      majors_subtree = self.class.new(splitted_keys[:majors], subtrees: splitted_subtrees[:majors], parent: self)

      self.keys = [splitted[:middle_key]]
      self.subtrees = [minors_subtree, majors_subtree]
    end

    [minors_subtree, majors_subtree, splitted[:middle_key]]
  end

  def split_key_in_middle
    {
      middle_key: keys[NODES[:middle_index]],
      keys: {
        minors: keys[0..(NODES[:middle_index] - 1)],
        majors: keys[(NODES[:middle_index] + 1)..-1],
      },
      subtrees: {
        minors: subtrees[0..NODES[:middle_index]],
        majors: subtrees[NODES[:middle_index] + 1..-1],
      }
    }
  end

  def find_first_ancestor_key_with_non_minimum_descendant_index
    current = self

    while current.parent && current.descendant_index == 0
      current = current.parent
    end

    current.parent.keys[current.descendant_index - 1] if current.parent
  end

  def find_first_ancestor_key_with_non_maximum_descendant_index
    current = self

    while current.parent && current.descendant_index == current.parent.keys_count
      current = current.parent
    end

    current.parent.keys[current.descendant_index] if current.parent
  end
end

items = (1..(2 ** 8 - 1)).map { |i| i * 10 }.shuffle

p items

@root = BTree.new(items.shift)

items.each_with_index do |item, i|
  puts i if i % 1000 == 0

  @root.add item
end

@root.as_graphviz; `open tree.png`
puts @root.valid?
puts "Tree average node size: #{"%3.1f" % (@root.average_keys_count)}"
