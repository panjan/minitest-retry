require 'test_helper'

class Minitest::RetryTest < Minitest::Test
  attr_accessor :reporter

  def setup
    self.reporter = Minitest::CompositeReporter.new
    self.reporter << Minitest::SummaryReporter.new
  end

  def capture_stdout
    out = StringIO.new
    $stdout = out
    yield
    out.string
  ensure
    $stdout = STDOUT
  end

  def test_display_retry_msg
    output = capture_stdout do
      retry_test = Class.new(Minitest::Test) do
        Minitest::Retry.use!
        def fail
          assert false, 'fail test'
        end
      end
      Minitest::Runnable.run_one_method(retry_test, :fail, self.reporter)
    end
    expect = <<-EOS
[MinitestRetry] retry 'fail' count: 1,  msg: fail test
[MinitestRetry] retry 'fail' count: 2,  msg: fail test
[MinitestRetry] retry 'fail' count: 3,  msg: fail test
    EOS

    refute reporter.passed?
    assert_equal expect, output
  end

  def test_display_retry_msg_for_unexpected_exception
    output = capture_stdout do
      retry_test = Class.new(Minitest::Test) do
        Minitest::Retry.use!
        def fail
          raise 'parsing error'
        end
      end
      Minitest::Runnable.run_one_method(retry_test, :fail, self.reporter)
    end
    expect = <<-EOS
[MinitestRetry] retry 'fail' count: 1,  msg: RuntimeError: parsing error\n    #{__FILE__}:45:in `fail'
[MinitestRetry] retry 'fail' count: 2,  msg: RuntimeError: parsing error\n    #{__FILE__}:45:in `fail'
[MinitestRetry] retry 'fail' count: 3,  msg: RuntimeError: parsing error\n    #{__FILE__}:45:in `fail'
    EOS

    refute reporter.passed?
    assert_equal expect, output
  end

  def test_if_test_is_successful_in_middle_of_retry
    output = capture_stdout do
      retry_test = Class.new(Minitest::Test) do
        @@counter = 0
        Minitest::Retry.use!
        def fail
          @@counter += 1
          assert_equal 3, @@counter
        end
      end
      Minitest::Runnable.run_one_method(retry_test, :fail, self.reporter)
    end
    expect = <<-EOS
[MinitestRetry] retry 'fail' count: 1,  msg: Expected: 3
  Actual: 1
[MinitestRetry] retry 'fail' count: 2,  msg: Expected: 3
  Actual: 2
    EOS

    assert reporter.passed?
    assert_equal expect, output
  end

  def test_having_to_only_specified_count_retry
    output = capture_stdout do
      retry_test = Class.new(Minitest::Test) do
        Minitest::Retry.use!(retry_count: 5)
        def fail
          assert false, 'fail test'
        end
      end
      Minitest::Runnable.run_one_method(retry_test, :fail, self.reporter)
    end
    expect = <<-EOS
[MinitestRetry] retry 'fail' count: 1,  msg: fail test
[MinitestRetry] retry 'fail' count: 2,  msg: fail test
[MinitestRetry] retry 'fail' count: 3,  msg: fail test
[MinitestRetry] retry 'fail' count: 4,  msg: fail test
[MinitestRetry] retry 'fail' count: 5,  msg: fail test
    EOS

    refute reporter.passed?
    assert_equal expect, output
  end

  def test_msg_does_not_display_when_verbose_false
    output = capture_stdout do
      retry_test = Class.new(Minitest::Test) do
        @@counter = 0
        Minitest::Retry.use!(verbose: false)
        def fail
          @@counter += 1
          assert_equal 3, @@counter
        end
      end
      Minitest::Runnable.run_one_method(retry_test, :fail, self.reporter)
    end

    assert reporter.passed?
    assert_empty output
  end

  def test_msg_does_not_display_when_do_not_use_retry
    output = capture_stdout do
      retry_test = Class.new(Minitest::Test) do
        def fail
          assert false, 'fail test'
        end
      end
      Minitest::Runnable.run_one_method(retry_test, :fail, self.reporter)
    end

    refute reporter.passed?
    assert_empty output
  end

  def test_donot_retry_skipped_Test
    output = capture_stdout do
      retry_test = Class.new(Minitest::Test) do
        Minitest::Retry.use!
        def skip_test
          skip 'skip test'
        end
      end
      Minitest::Runnable.run_one_method(retry_test, :skip_test, self.reporter)
    end

    assert reporter.passed?
    assert_empty output
  end
end

