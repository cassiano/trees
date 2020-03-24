require 'ap'
require 'ruby-graphviz'
require 'securerandom'

class Tree
  NEW_LINE = "\n"
  GUI_INDENT_SIZE = 1

  attr_accessor :value, :parent
  attr_reader :left, :right

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

  def height
    1 + [left&.height || 0, right&.height || 0].max
  end

  def count
    1 + (left&.count || 0) + (right&.count || 0)
  end

  def pre_order
    [value] + (left&.pre_order || []) + (right&.pre_order || [])
  end

  def in_order
    (left&.in_order || []) + [value] + (right&.in_order || [])
  end

  def post_order
    (left&.post_order || []) + (right&.post_order || []) + [value]
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

  def as_graphviz
    g = GraphViz.new(:G, type: :digraph)

    draw_graph_tree g, g.add_nodes(SecureRandom.uuid, label: value.to_s, shape: leaf? ? :doublecircle : :circle)

    g.output png: 'tree.png'
  end

  protected

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
  def initialize(value)
    super
  end

  def add_child(child_value)
    if child_value <= value
      if left
        left.add_child child_value
      else
        self.left = BST.new(child_value)
      end
    else
      if right
        right.add_child child_value
      else
        self.right = BST.new(child_value)
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

  # Change both left and right setters to private.
  protected :left=, :right=
end

# root = Tree.new(:a, left: Tree.new(:b), right: Tree.new(:c, left: Tree.new(:d)))

def reorder_by_collecting_middle_element(items)
  return items if items.size <= 2

  middle_index = items.size / 2

  ([items[middle_index]] + reorder_by_collecting_middle_element(items[0..middle_index-1]) + reorder_by_collecting_middle_element(items[middle_index+1..-1]))
end

# items = reorder_by_collecting_middle_element((1..(2 ** 6 - 1)).to_a)
items = (1..(2**5 - 1)).to_a.shuffle

@root = BST.new(items.shift)

items.each do |item|
  @root.add_child item
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
p @root.in_order
p @root.as_graphviz

`open tree.png`
