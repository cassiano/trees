# brew install graphviz
# gem install ruby-graphviz

require 'ruby-graphviz'
require 'securerandom'

# https://www.geeksforgeeks.org/introduction-of-b-tree-2/
class BTree
  DEBUG = true
  ASSERTIONS = true
  ALGORITHM = :reactive    # :proactive
  T = 3  # Minimum degree.
  NODES = {
    min: T - 1,   # Except for top root.
    max: 2 * T - 1,
    middle_index: T - 1,
  }
  ELLIPSIS = '…'

  include Comparable

  attr_reader :keys, :subtrees, :parent
  attr_accessor :merged_at

  def initialize(key_or_keys = [], subtrees: [], parent: nil)
    keys = [*key_or_keys]

    self.parent = parent
    self.keys = keys
    self.subtrees = subtrees
  end

  # https://www.geeksforgeeks.org/insert-operation-in-b-tree/
  def add(key)
    result = begin
      case ALGORITHM
        when :proactive
          if full?
            minors_subtree, majors_subtree, middle_key = split_child(key)

            target_subtree = key <= middle_key ? minors_subtree : majors_subtree

            target_subtree.add key
          else
            insertion_index = find_subtree_index(key)
            y = subtrees[insertion_index]

            if leaf?
              insert_key key, insertion_index

              self
            elsif y
              y.add key
            else
              raise "Empty node reached when adding key `#{key}` to non-leaf node #{self}."
            end
          end
        when :reactive
          insertion_index = find_subtree_index(key)
          y = subtrees[insertion_index]

          if leaf?
            if full?
              minors_subtree, majors_subtree, middle_key = split_child(key)

              target_subtree = key <= middle_key ? minors_subtree : majors_subtree

              target_subtree.add key
            else
              insert_key key, insertion_index

              self
            end
          elsif y
            y.add key
          else
            raise "Empty node reached when adding key `#{key}` to non-leaf node #{self}."
          end
      end
    end

    if ASSERTIONS
      raise "Invalid tree after adding #{key} to node #{self}." unless top_root.valid?
    end

    result
  end

  def delete(k)
    if ASSERTIONS
      raise "Invalid node size before deleting #{k} from node #{self}." if !top_root? && minimum_node_size_reached?
    end

    result = begin
      key_found, subtree_index = key_found?(k)

      if key_found
        if leaf?
          delete_from_leaf_node subtree_index
        else
          delete_from_non_leaf_node k, subtree_index
        end
      else
        if non_leaf?
          find_and_delete_from_subtree k, subtree_index
        else
          raise "Key #{k} not found."
        end
      end
    end

    if ASSERTIONS
      raise "Invalid tree after deleting #{k} from node #{self}." unless top_root.valid?
    end

    result
  end

  def ancestors
    [self].tap do |ancestors_path|
      ancestors_path.concat parent.ancestors unless top_root?
    end
  end

  def top_root
    parent&.top_root || self
  end

  def top_root?
    !parent
  end

  def predecessor
    leaf? ? keys[-1] : subtrees[keys_count].predecessor
  end

  def successor
    leaf? ? keys[0] : subtrees[0].successor
  end

  def maximum_node_size_reached?
    keys_count == NODES[:max]
  end

  alias_method :full?, :maximum_node_size_reached?

  def minimum_node_size_reached?
    keys_count == minimum_keys_count
  end

  def within_size_limits?
    (minimum_keys_count..NODES[:max]).include? keys_count
  end

  def keys_count
    keys.size
  end

  def subtrees_count
    subtrees.size
  end

  def leaf?
    subtrees ? subtrees.empty? : true
  end

  def non_leaf?
    !leaf?
  end

  def valid?
    if leaf?
      within_size_limits?
    else
      within_size_limits? &&
        subtrees_count == keys_count + 1 &&
        (tree_height = height) && subtrees.all? { |subtree| subtree.height == tree_height - 1 } &&
        subtrees.all? { |subtree| subtree.parent == self } &&
        keys.each_with_index.all? do |key, i|
          (
            subtrees[i    ].traverse.all? { |subtree_key| subtree_key <= key } &&
            subtrees[i + 1].traverse.all? { |subtree_key| subtree_key  > key }
          )
        end &&
        subtrees.all?(&:valid?)
    end
  end

  def total_keys_count
    keys_count + subtrees.map(&:total_keys_count).reduce(0, :+)
  end

  def total_nodes_count
    1 + subtrees.map(&:total_nodes_count).reduce(0, :+)
  end

  def average_keys_count
    total_keys_count.to_f / total_nodes_count if total_nodes_count > 0
  end

  def find(k)
    key_found, subtree_index = key_found?(k)

    if key_found
      self
    elsif non_leaf?
      subtrees[subtree_index].find k
    else
      raise "Key #{k} not found."
    end
  end

  def descendant_index
    parent&.find_subtree_index keys[0]    # The key is not relevant. We could have picked any of the current node.
  end

  def height
    (subtrees[0]&.height || 0) + 1
  end

  def traverse
    if leaf?
      keys
    else
      subtrees.each_with_index.reduce([]) do |memo, (subtree, i)|
        memo + subtree.traverse + (i < keys_count ? [keys[i]] : [])
      end
    end
  end

  # https://stackoverflow.com/questions/25488902/what-happens-when-you-use-string-interpolation-in-ruby
  def to_s
    { keys: keys, subtrees: subtrees.map(&:to_s) }.to_s
  end

  alias_method :inspect, :to_s

  def as_graphviz(image_file = 'tree.png')
    g = GraphViz.new(:G, type: :digraph)

    draw_graph_tree g, g.add_node(SecureRandom.uuid, label: keys.join(', '), shape: leaf? ? :rectangle : :ellipse)

    g.output png: image_file
  end

  def display
    as_graphviz
    `open tree.png`
  end

  def <=>(another_btree)
    if BTree === another_btree
      if (parent_comparison = parent <=> another_btree.parent) == 0
        if (keys_comparison = keys <=> another_btree.keys) == 0
          subtrees <=> another_btree.subtrees
        else
          keys_comparison
        end
      else
        parent_comparison
      end
    end
  end

  protected

  attr_writer :parent

  def find_subtree_index(key)
    keys.index { |v| key <= v } || keys_count
  end

  def find_subtree(key)
    subtrees[find_subtree_index(key)] unless subtrees.empty?
  end

  def insert_key(key, position)
    raise "Maximum node size exceeded for subtree #{self} when inserting key `#{key}` at position #{position}." if full?

    keys.insert position, key
  end

  def insert_subtree(subtree, position)
    raise "Maximum node size exceeded for subtree #{self} when inserting subtree `#{subtree}` at position #{position}." if subtrees_count + 1 > NODES[:max] + 1

    if subtree
      subtrees.insert position, subtree
      subtree.parent = self
    end
  end

  def delete_key(position)
    keys.delete_at position
  end

  def delete_subtree(position)
    subtrees.delete_at position
  end

  def keys=(new_keys)
    @keys = new_keys

    raise "Invalid node size for subtree #{self} when setting keys `#{keys.join(', ')}`." unless within_size_limits?
  end

  def subtrees=(new_subtrees)
    raise "Subtrees size (#{new_subtrees.size}) must match number of keys (#{keys_count}) + 1." if new_subtrees.any? && new_subtrees.size != keys_count + 1

    @subtrees = new_subtrees

    subtrees.each { |subtree| subtree.parent = self }
  end

  def draw_graph_tree(g, root_node)
    subtrees.each_with_index do |subtree, index|
      # https://www.graphviz.org/doc/info/shapes.html
      current_node = g.add_node(SecureRandom.uuid, label: subtree.keys.join(', '), shape: subtree.leaf? ? :rectangle : :ellipse)

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
      g.add_edges root_node, current_node, label: edge_label

      subtree.draw_graph_tree g, current_node
    end
  end

  def split_child(key)
    splitted = split_keys_and_subtrees
    splitted_keys = splitted[:keys]
    splitted_subtrees = splitted[:subtrees]

    if top_root?
      minors_subtree = self.class.new(splitted_keys[:minors], subtrees: splitted_subtrees[:minors], parent: self)
      majors_subtree = self.class.new(splitted_keys[:majors], subtrees: splitted_subtrees[:majors], parent: self)

      self.keys = [splitted[:middle_key]]
      self.subtrees = [minors_subtree, majors_subtree]
    else
      if ALGORITHM == :reactive
        parent.split_child(key) if parent.full?
      end

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
    end

    [minors_subtree, majors_subtree, splitted[:middle_key]]
  end

  def increment_keys_size
    puts "Incrementing keys size of node #{self}." if DEBUG

    stored_descendant_index = descendant_index
    immediate_siblings = find_immediate_siblings(stored_descendant_index)
    candidate_siblings = immediate_siblings.reject { |sibling| sibling[:subtree].minimum_node_size_reached? }

    puts "#{candidate_siblings.size} candidate siblings(s) found." if DEBUG

    if candidate_siblings.any?
      # Case 3a.
      puts "Case 3a detected." if DEBUG

      sibling = candidate_siblings.sample   # Pick any candidate sibling.

      puts "#{sibling[:type]} sibling being used.#{' PS: randomly picked from both siblings.' if candidate_siblings.size > 1}" if DEBUG

      case sibling[:type]
        when :left
          move_key_from_left_sibling sibling, stored_descendant_index
        when :right
          move_key_from_right_sibling sibling, stored_descendant_index
      end
    else
      # Case 3b.
      puts "Case 3b detected." if DEBUG

      sibling = immediate_siblings.sample   # Pick any immediate sibling.

      puts "#{sibling[:type]} sibling being used.#{' PS: randomly picked from both siblings.' if immediate_siblings.size > 1}" if DEBUG

      if parent.top_root? && parent.keys_count == 1
        puts "Top root with a single key being merged." if DEBUG

        parent_key = parent.keys[0]

        case sibling[:type]
          when :left
            parent.keys = sibling[:subtree].keys + [parent_key] + keys
            parent.subtrees = sibling[:subtree].subtrees + subtrees
          when :right
            parent.keys = keys + [parent_key] + sibling[:subtree].keys
            parent.subtrees = subtrees + sibling[:subtree].subtrees
        end

        # Warn the caller of this method that the current node has been exceptionally merged at its parent, so the delete operation that follows takes place there. See methods
        # `find_and_delete_from_subtree` and `delete_predecessor_or_successor` for details.
        self.merged_at = parent
      else
        case sibling[:type]
          when :left
            parent_key = parent.keys[stored_descendant_index - 1]

            self.keys = sibling[:subtree].keys + [parent_key] + keys
            self.subtrees = sibling[:subtree].subtrees + subtrees

            parent.delete_key stored_descendant_index - 1
            parent.delete_subtree stored_descendant_index - 1
          when :right
            parent_key = parent.keys[stored_descendant_index]

            self.keys += [parent_key] + sibling[:subtree].keys
            self.subtrees += sibling[:subtree].subtrees

            parent.delete_key stored_descendant_index
            parent.delete_subtree stored_descendant_index + 1
        end
      end
    end
  end

  def delete_predecessor
    delete_predecessor_or_successor :predecessor
  end

  def delete_successor
    delete_predecessor_or_successor :successor
  end

  def delete_predecessor_or_successor(type)
    searched_index = type == :predecessor ? -1 : 0

    if leaf?
      # Return the key being deleted.
      keys[searched_index].tap do
        delete_from_leaf_node searched_index
      end
    else
      subtree = subtrees[searched_index]   # Store the subtree in a (temporary) variable, because it may change its index after an eventual merge (case 3b).

      subtree.increment_keys_size if subtree.minimum_node_size_reached?

      (subtree.merged_at || subtree).delete_predecessor_or_successor type
    end
  end

  private

  def minimum_keys_count
    if !top_root?
      NODES[:min]
    elsif non_leaf?
      1
    else
      0
    end
  end

  def key_found?(k)
    subtree_index = find_subtree_index(k)

    [subtree_index < keys_count && keys[subtree_index] == k, subtree_index]
  end

  def move_key_from_left_sibling(sibling, stored_descendant_index)
    # Move the left sibling's highest key up (to its parent node) and the parent node's respective key down to the left of current node.
    parent_key = parent.keys[stored_descendant_index - 1]
    left_sibling_highest_key = sibling[:subtree].keys[-1]
    left_sibling_highest_subtree = sibling[:subtree].subtrees[-1]

    sibling[:subtree].delete_key -1
    sibling[:subtree].delete_subtree -1
    parent.keys[stored_descendant_index - 1] = left_sibling_highest_key

    insert_key parent_key, 0
    insert_subtree left_sibling_highest_subtree, 0
  end

  def move_key_from_right_sibling(sibling, stored_descendant_index)
    # Move the right sibling's lowest key up (to its parent node) and the parent node's respective key down to the right of current node.
    parent_key = parent.keys[stored_descendant_index]
    right_sibling_lowest_key = sibling[:subtree].keys[0]
    right_sibling_lowest_subtree = sibling[:subtree].subtrees[0]

    sibling[:subtree].delete_key 0
    sibling[:subtree].delete_subtree 0
    parent.keys[stored_descendant_index] = right_sibling_lowest_key

    insert_key parent_key, -1
    insert_subtree right_sibling_lowest_subtree, -1
  end

  def find_immediate_siblings(stored_descendant_index)
    [].tap do |siblings|
      siblings << { subtree: parent.subtrees[stored_descendant_index - 1], type: :left  } if stored_descendant_index > 0                    # Left sibling.
      siblings << { subtree: parent.subtrees[stored_descendant_index + 1], type: :right } if stored_descendant_index < parent.keys_count    # Right sibling.

      puts "#{siblings.size} total sibling(s) found." if DEBUG
    end
  end

  def delete_from_leaf_node(subtree_index)
    # Case 1.
    puts "Case 1 detected." if DEBUG

    delete_key subtree_index
  end

  def delete_from_non_leaf_node(k, subtree_index)
    # Check if child y that precedes k in current node has at least T keys.
    y = subtrees[subtree_index]

    if !y.minimum_node_size_reached?
      # Case 2a.
      puts "Case 2a detected." if DEBUG

      k0 = y.delete_predecessor

      keys[subtree_index] = k0
    else
      # Check if child z that succedes k in current node has at least T keys.
      z = subtrees[subtree_index + 1]

      if !z.minimum_node_size_reached?
        # Case 2b.
        puts "Case 2b detected." if DEBUG

        k0 = z.delete_successor

        keys[subtree_index] = k0
      else
        # Case 2c. Merge k and all keys of z into y.
        puts "Case 2c detected." if DEBUG

        if top_root? && keys_count == 1
          puts "Top root with a single key being merged." if DEBUG

          # Do the merging in the current node, instead of the y node (see `else` condition below).
          self.keys = y.keys + [k] + z.keys
          self.subtrees = y.subtrees + z.subtrees

          delete k
        else
          y.keys += [k] + z.keys
          y.subtrees += z.subtrees

          delete_key subtree_index
          delete_subtree subtree_index + 1

          y.delete k
        end
      end
    end
  end

  def find_and_delete_from_subtree(k, subtree_index)
    subtree = subtrees[subtree_index]   # Store the subtree in a (temporary) variable, because it may change its index after an eventual merge (case 3b).

    subtree.increment_keys_size if subtree.minimum_node_size_reached?

    (subtree.merged_at || subtree).delete k
  end

  def split_keys_and_subtrees
    {
      middle_key: keys[NODES[:middle_index]],
      keys: {
        minors: keys[0..(NODES[:middle_index] - 1)],
        majors: keys[(NODES[:middle_index] + 1)..-1],
      },
      subtrees: {
        minors: subtrees[0..NODES[:middle_index]] || [],
        majors: subtrees[NODES[:middle_index] + 1..-1] || [],
      }
    }
  end

  def find_first_ancestor_key_with_non_minimum_descendant_index
    current = self

    while !current.top_root? && current.descendant_index == 0
      current = current.parent
    end

    current.parent.keys[current.descendant_index - 1] unless current.top_root?
  end

  def find_first_ancestor_key_with_non_maximum_descendant_index
    current = self

    while !current.top_root? && current.descendant_index == current.parent.keys_count
      current = current.parent
    end

    current.parent.keys[current.descendant_index] unless current.top_root?
  end
end

if __FILE__ == $0
  @items = (0..(2 ** 10 - 1)).map { |i| i * 10 }.shuffle

  p @items

  @root = BTree.new(@items[0])

  @items[1..-1].each_with_index do |item, i|
    puts i if i % 1000 == 0

    @root.add item
  end

  @root.display
  puts "Tree average node size: #{"%3.1f" % (@root.average_keys_count)}"

  @items.shuffle.each_with_index { |key, i| puts "---> (#{i + 1}) Deleting #{key}..."; @root.delete key }

  puts "\nTotal keys count: #{@root.total_keys_count}"
end
