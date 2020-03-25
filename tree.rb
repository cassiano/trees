require 'ap'
require 'ruby-graphviz'
require 'securerandom'

class Tree
  NEW_LINE = "\n"
  GUI_INDENT_SIZE = 1

  attr_accessor :value
  attr_reader :left, :right, :parent

  def initialize(value, left: nil, right: nil)
    @value = value
    @left = left
    @right = right

    left&.parent = self
    right&.parent = self
  end

  def left=(new_left)
    @left = new_left
    left&.parent = self
  end

  def right=(new_right)
    @right = new_right
    right&.parent = self
  end

  def leaf?
    !left && !right
  end

  def top_root
    parent&.top_root || self
  end

  def balanced?
    ((left&.height || 0) - (right&.height || 0)).abs <= 1 && (left ? left.balanced? : true) && (right ? right.balanced? : true)   # Do not use `left&.balanced? || true`.
  end

  def descendant_type
    if parent
      if parent.left == self
        :left
      elsif parent.right == self
        :right
      end
    end
  end

  def height
    1 + [left&.height || 0, right&.height || 0].max
  end

  def count
    1 + (left&.count || 0) + (right&.count || 0)
  end

  def pre_order(&block)
    [block ? block.call(self) : self] + (left&.pre_order(&block) || []) + (right&.pre_order(&block) || [])
  end

  def in_order(&block)
    (left&.in_order(&block) || []) + [block ? block.call(self) : self] + (right&.in_order(&block) || [])
  end

  def post_order(&block)
    (left&.post_order(&block) || []) + (right&.post_order(&block) || []) + [block ? block.call(self) : self]
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

  def fill_factor
    count.to_f / (2 ** height - 1)
  end

  def level_values(level, range: , parent: nil, type: nil)
    mean_position = (range[0] + range[1]) / 2

    if level == 1
      [{ value: value, parent: parent&.value, type: type, position: mean_position, range: range }]
    else
      (left&.level_values(level - 1, parent: self, type: :left, range: [range[0], mean_position]) || []) +
        (right&.level_values(level - 1, parent: self, type: :right, range: [mean_position, range[1]]) || [])
    end
  end

  # # Non-recursive version, both more complex and slower than the recursive one.
  # def as_tree_gui(width:)
  #   tree_height = height
  #   canvas = (tree_height * 2).times.inject([]) { |memo, _| memo << [' ' * width, NEW_LINE].join }
  #
  #   (1..tree_height).each do |level|
  #     level_values(level, range: [1, width]).each do |node_data|
  #       text_value = node_data[:value].to_s
  #       base_row = (level - 1) * 2
  #
  #       if level > 1
  #         if node_data[:type] == :left
  #           fill_canvas canvas, base_row, '┌' + '─' * (node_data[:range][1] - node_data[:position] - 1) + '┘', node_data[:position] - 1
  #         else    # right
  #           if canvas[base_row + 0][node_data[:range][0] - 1] == ' '
  #             fill_canvas canvas, base_row, '└' + '─' * (node_data[:position] - node_data[:range][0] - 1) + '┐', node_data[:range][0] - 1
  #           else
  #             fill_canvas canvas, base_row, '┴' + '─' * (node_data[:position] - node_data[:range][0] - 1) + '┐', node_data[:range][0] - 1
  #           end
  #         end
  #       end
  #
  #       fill_canvas canvas, base_row + 1, text_value, node_data[:position] - 1
  #     end
  #   end
  #
  #   canvas
  # end

  def as_tree_gui(width:)
    return "Tree is too high and cannot be drawn!" if (tree_height = height) > Math.log(width, 2).to_int

    (tree_height * 2 - 1).times.inject([]) { |memo, _| memo << [' ' * width, NEW_LINE].join }.tap do |canvas|
      draw_tree canvas, 0..(width - 1), 1
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
  def as_graphviz
    g = GraphViz.new(:G, type: :digraph)

    draw_graph_tree g, g.add_nodes(SecureRandom.uuid, label: value.to_s, shape: leaf? ? :doublecircle : :circle)

    g.output png: 'tree.png'
  end

  protected

  attr_writer :parent

  def draw_tree(canvas, range, level, type = nil)
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

      left&.draw_tree canvas, range.begin..mean_position, level + 1, :left
      right&.draw_tree canvas, mean_position..range.end, level + 1, :right
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
        # g.add_edges root_node, g.add_nodes(SecureRandom.uuid, label: ' ' * 5, shape: :none), style: :invis
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
end

class BST < Tree
  def add_child(child_value)
    if child_value <= value
      if left
        left.add_child child_value
      else
        self.class.new(child_value).tap do |new_child|
          self.left = new_child
        end
      end
    else
      if right
        right.add_child child_value
      else
        self.class.new(child_value).tap do |new_child|
          self.right = new_child
        end
      end
    end
  end

  def search(searched_value)
    if searched_value == value
      self
    elsif searched_value <= value
      left&.search searched_value
    else
      right&.search searched_value
    end
  end

  def max
    right&.max || value
  end

  def min
    left&.min || value
  end

  protected :left=, :right=, :value=
end

# https://www.geeksforgeeks.org/avl-tree-set-1-insertion/
class AvlTree < BST
  attr_accessor :ancestors_checked

  def add_child(child_value)
    puts "Adding #{child_value} to sub-tree #{value}"

    super.tap do |new_child|                                    # w
      unless new_child.ancestors_checked
        puts "Checking ancestors path after adding #{child_value} to sub-tree #{value}"

        ancestors_path = [{ node: new_child, descendant_type: new_child.descendant_type }]

        found_unbalanced_node = loop do
          if (ancestor = ancestors_path.last[:node].parent)
            ancestors_path << { node: ancestor, descendant_type: ancestor.descendant_type }

            break true unless ancestor.balanced?
          else
            break false
          end
        end

        if found_unbalanced_node
          if ancestors_path.size >= 3
            unbalanced_node = ancestors_path[-1]                  # z
            unbalanced_node_child = ancestors_path[-2]            # y
            unbalanced_node_grand_child = ancestors_path[-3]      # x

            puts "Unbalanced node found with value #{unbalanced_node[:node].value}"

            case [unbalanced_node_child[:descendant_type], unbalanced_node_grand_child[:descendant_type]]
              when [:left, :left]
                unbalanced_node[:node].rotate :right
              when [:left, :right]
                unbalanced_node_child[:node].rotate :left
                unbalanced_node[:node].rotate :right
              when [:right, :right]
                unbalanced_node[:node].rotate :left
              when [:right, :left]
                unbalanced_node_child[:node].rotate :right
                unbalanced_node[:node].rotate :left
            end
          else
            raise "Unbalanced node found with value #{ancestors_path[-1][:node].value}, but ancestors path size is < 3 (#{ancestors_path.size})"
          end
        else
          puts "No unbalanced nodes found!"
        end

        new_child.ancestors_checked = true
      end
    end
  end

  protected

  def replace_parent(previous_root, previous_root_parent)
    if previous_root_parent
      if previous_root_parent.left == previous_root
        previous_root_parent.left = self
      elsif previous_root_parent.right == previous_root
        previous_root_parent.right = self
      end
    else
      self.parent = nil
    end
  end

  def rotate(direction)
    puts "Rotating #{direction} node #{value}..."

    previous_parent = parent

    case direction
      when :left
        previous_right = right                                  # y
        self.right = previous_right.left                        # T2
        previous_right.left = self                              # x
        previous_right.replace_parent self, previous_parent     # New root
      when :right
        previous_left = left                                    # x
        self.left = previous_left.right                         # T2
        previous_left.right = self                              # y
        previous_left.replace_parent self, previous_parent      # New root
    end
  end
end

# root = Tree.new(:a, left: Tree.new(:b), right: Tree.new(:c, left: Tree.new(:d)))

def reorder_by_collecting_middle_element(items)
  return items if items.size <= 2

  middle_index = items.size / 2

  ([items[middle_index]] + reorder_by_collecting_middle_element(items[0..middle_index-1]) + reorder_by_collecting_middle_element(items[middle_index+1..-1]))
end

# items = reorder_by_collecting_middle_element((1..(2**6 - 1)).to_a)
items = (1..(2**6 - 1)).to_a.shuffle

p items

@root = AvlTree.new(items.shift)

items.each do |item|
  @root.add_child item

  # Chech if root has changed and update it, if applicable.
  if @root != (new_root = @root.top_root)
    @root = new_root
  end

  raise "Tree became unbalanced after adding node #{item}!" unless @root.pre_order.all?(&:balanced?)
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
p @root.in_order &:value
p @root.as_graphviz

`open tree.png`
