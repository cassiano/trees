# brew install graphviz
# gem install ruby-graphviz

require 'ruby-graphviz'
require 'securerandom'

# https://www.geeksforgeeks.org/introduction-of-b-tree-2/
class BTree
  ALGORITHM = :reactive    # :proactive
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
    self.subtrees = subtrees
  end

  # https://www.geeksforgeeks.org/insert-operation-in-b-tree/
  def add(key)
    case ALGORITHM
      when :proactive
        if full?
          minors_subtree, majors_subtree, middle_key = split_child(key)

          target_subtree = key <= middle_key ? minors_subtree : majors_subtree

          target_subtree.add key
        else
          insertion_index = find_subtree_index(key)
          y = subtrees[insertion_index] if subtrees

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
        y = subtrees[insertion_index] if subtrees

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

  def delete(key)
    subtree_index = find_subtree_index(key)

    if subtree_index < keys_count && keys[subtree_index] == key
      # Key found.
      if leaf?
        if minimum_node_size_reached?
          parent_index = descendant_index

          siblings = []
          siblings << { subtree: parent.subtrees[parent_index - 1], type: :left } if parent_index > 0                     # Left sibling.
          siblings << { subtree: parent.subtrees[parent_index + 1], type: :right } if parent_index < parent.keys_count    # Right sibling.

          puts "#{siblings.size} total sibling(s) found." if DEBUG

          siblings.reject! { |sibling| sibling[:subtree].minimum_node_size_reached? }

          puts "#{siblings.size} valid siblings(s) found." if DEBUG

          if siblings.any?
            # Case 3a.
            puts "Case 3a detected." if DEBUG

            sibling = siblings[0]   # Pick the 1st valid sibling.

            case sibling[:type]
              when :left
                puts "Left sibling being used." if DEBUG

                # Move the left sibling's highest key up (to its parent node) and the parent node's respective key down to the left of current node.
                parent_key = parent.keys[parent_index - 1]
                highest_key = sibling[:subtree].keys[sibling[:subtree].keys_count - 1]

                # puts "parent_key: #{parent_key}, highest_key: #{highest_key}" if DEBUG

                sibling[:subtree].keys.delete_at -1
                parent.keys[parent_index - 1] = highest_key

                insert_key parent_key, 0
                keys.delete_at subtree_index + 1
              when :right
                puts "Right sibling being used." if DEBUG

                # Move the right sibling's lowest key up (to its parent node) and the parent node's respective key down to the right of current node.
                parent_key = parent.keys[parent_index]
                lowest_key = sibling[:subtree].keys[0]

                # puts "parent_key: #{parent_key}, lowest_key: #{lowest_key}" if DEBUG

                sibling[:subtree].keys.delete_at 0
                parent.keys[parent_index] = lowest_key

                insert_key parent_key, -1
                keys.delete_at subtree_index
            end
          else
            # Case 3b.
            puts "Case 3b detected." if DEBUG

            # ...
          end
        else
          # Case 1.
          puts "Case 1 detected." if DEBUG

          delete_key subtree_index
        end
      else
        # Check if child y that precedes key in current node has at least T keys.
        y = subtrees[subtree_index]

        if !y.minimum_node_size_reached?
          # Case 2a.
          puts "Case 2a detected." if DEBUG

          k0 = y.predecessor
          y.delete k0

          keys[subtree_index] = k0
        else
          # Check if child z that succedes key in current node has at least T keys.
          z = subtrees[subtree_index + 1]

          if !z.minimum_node_size_reached?
            # Case 2b.
            puts "Case 2b detected." if DEBUG

            k0 = z.successor
            z.delete k0

            keys[subtree_index] = k0
          else
            puts "Case 2c detected." if DEBUG

            # Case 2c. Merge key and all of z into y.
            y.keys += [key] + z.keys
            y.subtrees += z.subtrees unless y.leaf? && z.leaf?

            keys.delete_at subtree_index
            subtrees.delete_at subtree_index + 1

            y.delete key
          end
        end
      end
    elsif non_leaf?
      subtrees[subtree_index].delete key
    else
      raise "Key #{key} not found in non-leaf node #{self}."
    end
  end

  def top_root
    parent&.top_root || self
  end

  def predecessor
    leaf? ? keys[keys_count - 1] : subtrees[keys_count].predecessor
  end

  def successor
    leaf? ? keys[0] : subtrees[0].successor
  end

  def maximum_node_size_reached?
    keys_count == NODES[:max]
  end

  alias_method :full?, :maximum_node_size_reached?

  def minimum_node_size_reached?
    keys_count == (parent ? NODES[:min] : 1)
  end

  def within_size_limits?
    ((parent ? NODES[:min] : 1)..NODES[:max]).include? keys_count
  end

  def keys_count
    keys.size
  end

  def subtrees_count
    subtrees&.size || 0
  end

  def leaf?
    !subtrees
  end

  def non_leaf?
    !leaf?
  end

  def valid?
    leaf? ? !subtrees : subtrees_count == keys_count + 1 &&
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
    (subtrees ? subtrees[0].height : 0) + 1
  end

  def in_order
    if leaf?
      keys
    else
      subtrees.each_with_index.reduce([]) do |memo, (subtree, i)|
        memo + subtree.in_order + (i < keys_count ? [keys[i]] : [])
      end
    end
  end

  # https://stackoverflow.com/questions/25488902/what-happens-when-you-use-string-interpolation-in-ruby
  def to_s
    { keys: keys, subtrees: subtrees&.map(&:to_s) }.to_s
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

  protected

  attr_writer :parent

  def find_subtree_index(key)
    keys.index { |v| key <= v } || keys_count
  end

  def find_subtree(key)
    subtrees[find_subtree_index(key)] if subtrees
  end

  def insert_key(key, position)
    raise "Maximum node size exceeded for subtree #{self} when inserting key `#{key}` at position #{position}." if full?

    keys.insert position, key
  end

  def delete_key(position)
    raise "Invalid index #{position} when deleting key." if position > keys_count - 1

    keys.delete_at position
  end

  def insert_subtree(subtree, position)
    subtrees.insert(position, subtree) if subtree
  end

  def subtrees=(new_subtrees)
    raise "Subtrees size (#{new_subtrees.size}) must match number of keys (#{keys_count}) + 1." if new_subtrees && new_subtrees.size != keys_count + 1

    @subtrees = new_subtrees

    new_subtrees&.each { |subtree| subtree&.parent = self }
  end

  def keys=(new_keys)
    raise "Minimum node size not reached for subtree #{self} when setting keys `#{keys.join(', ')}`." if new_keys.size < (parent ? NODES[:min] : 1)
    raise "Maximum node size exceeded for subtree #{self} when setting keys `#{keys.join(', ')}`." if new_keys.size > NODES[:max]

    @keys = new_keys
  end

  def draw_graph_tree(g, root_node)
    subtrees&.each_with_index do |subtree, index|
      raise "Invalid parent #{parent} for sub-tree #{subtree}." if subtree.parent != self

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

    # Top root key?
    if parent
      # No.
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
    else
      # Yes.
      minors_subtree = self.class.new(splitted_keys[:minors], subtrees: splitted_subtrees[:minors], parent: self)
      majors_subtree = self.class.new(splitted_keys[:majors], subtrees: splitted_subtrees[:majors], parent: self)

      self.keys = [splitted[:middle_key]]
      self.subtrees = [minors_subtree, majors_subtree]
    end

    [minors_subtree, majors_subtree, splitted[:middle_key]]
  end

  def insert_subtree(subtree, position)
    raise "Maximum node size exceeded for subtree #{self} when inserting subtree `#{subtree}` at position #{position}." if subtrees_count + 1 > NODES[:max] + 1

    subtrees.insert position, subtree
  end

  private

  def split_keys_and_subtrees
    {
      middle_key: keys[NODES[:middle_index]],
      keys: {
        minors: keys[0..(NODES[:middle_index] - 1)],
        majors: keys[(NODES[:middle_index] + 1)..-1],
      },
      subtrees: {
        minors: subtrees && subtrees[0..NODES[:middle_index]],
        majors: subtrees && subtrees[NODES[:middle_index] + 1..-1],
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

items = (1..(2 ** 6 - 1)).map { |i| i * 10 }.shuffle

p items

@root = BTree.new(items.shift)

items.each_with_index do |item, i|
  puts i if i % 1000 == 0

  @root.add item
end

@root.display
puts @root.valid?
puts "Tree average node size: #{"%3.1f" % (@root.average_keys_count)}"
