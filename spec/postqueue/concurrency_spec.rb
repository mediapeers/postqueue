require "spec_helper"

describe "concurrency" do
  # -- helper methods ---------------------------------------------------------

  def processed_ids
    File.read(LOG_FILE).split("\n").map(&:to_i)
  end

  def benchmark(msg, &block)
    realtime = Benchmark.realtime(&block)
    STDERR.puts "#{msg}: #{"%.3f msecs" % realtime}"
    realtime
  end

  LOG_FILE = "log/test-runner.log"

  # Each runner writes the processed message into the LOG_FILE
  def runner
    ActiveRecord::Base.connection_pool.with_connection do |conn|
      log = File.open(LOG_FILE, "a")
      queue = Postqueue::Base.new
      queue.process_until_empty { |op, entity_ids| sleep(0.0001); log.write "#{entity_ids.first}\n" }
      log.close
    end
  rescue => e
    STDERR.puts "runner aborts: #{e}, from #{e.backtrace.first}"
  end

  def run_scenario(cnt, n_threads)
    FileUtils.rm_rf LOG_FILE

    queue = Postqueue::Base.new
    benchmark "enqueuing #{cnt} ops" do
      queue.enqueue op: "myop", entity_id: (1..cnt)
    end

    benchmark "processing #{cnt} ops with #{n_threads} threads" do
      if n_threads == 0
        runner
      else
        n_threads.times.map { Thread.new { runner } }.each(&:join)
      end
    end
  end

  # -- tests start here -------------------------------------------------------

  it "runs faster with multiple runners", transactions: false do
    # For small cnt values here the test below actually fails.
    cnt = 1000

    t0_runtime = run_scenario cnt, 0
    expect(processed_ids).to contain_exactly(*(1..cnt).to_a)

    t4_runtime = run_scenario cnt, 4
    expect(processed_ids).to contain_exactly(*(1..cnt).to_a)
    expect(t4_runtime).to be < t0_runtime * 0.8
  end
end
