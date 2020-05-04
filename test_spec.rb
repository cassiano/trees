require 'colored'

class TestExpectation
  attr_reader :test_title, :actual_value

  def initialize(test_title, actual_value)
    @test_title = test_title
    @actual_value = actual_value
  end

  def to_be_true(expected_value)
    if actual_value.send(expected_value)
      passed
    else
      failed "Expected: `#{expected_value}` to return a truthy value."
    end

    self
  end

  def not_to_be_true(expected_value)
    unless actual_value.send(expected_value)
      passed
    else
      failed "Expected: `#{expected_value}` not to return a truthy value."
    end

    self
  end

  def to_equal(expected_value)
    if actual_value == expected_value
      passed
    else
      failed "Expected: `#{expected_value}`, \nGot `#{actual_value}`."
    end

    self
  end

  def not_to_equal(expected_value)
    if actual_value != expected_value
      passed
    else
      failed "Expected: `#{expected_value}`, \nGot `#{actual_value}`."
    end

    self
  end

  private

  def passed
    puts "--> `#{test_title}` test passed.".green
  end

  def failed(message)
    puts "--> `#{test_title}` test failed.\n#{message}".red
  end
end

def expect(test_title, &block)
  begin
    TestExpectation.new test_title, block.call
  rescue => e
    TestExpectation.new test_title, "Exception raised: `#{e.message}`"
  end
end
