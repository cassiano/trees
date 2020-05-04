require 'colored'

class TestExpectation
  attr_reader :test_title, :actual_value

  def initialize(test_title, actual_value)
    @test_title = test_title
    @actual_value = actual_value
  end

  def to_be(expected_value)
    if actual_value.send(expected_value)
      puts "--> `#{test_title}` test passed.".green
    else
      puts "--> `#{test_title}` test failed.\nExpected: `#{expected_value}` to return true.".red
    end

    self
  end

  def not_to_be(expected_value)
    unless actual_value.send(expected_value)
      puts "--> `#{test_title}` test passed.".green
    else
      puts "--> `#{test_title}` test failed.\nExpected: `#{expected_value}` to return false.".red
    end

    self
  end

  def to_equal(expected_value)
    if actual_value == expected_value
      puts "--> `#{test_title}` test passed.".green
    else
      puts "--> `#{test_title}` test failed.\nExpected: `#{expected_value}`, \nGot `#{actual_value}`.".red
    end

    self
  end

  def not_to_equal(expected_value)
    if actual_value != expected_value
      puts "--> `#{test_title}` test passed.".green
    else
      puts "--> `#{test_title}` test failed.\nExpected: `#{expected_value}`, \nGot `#{actual_value}`.".red
    end

    self
  end
end

def expect(test_title, &block)
  begin
    TestExpectation.new test_title, block.call
  rescue => e
    TestExpectation.new test_title, "Exception raised: `#{e.message}`"
  end
end
