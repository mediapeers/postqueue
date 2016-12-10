require 'spec_helper'

describe "::queue.process_one" do
  let(:queue) { Postqueue.new }

  class E < RuntimeError; end

  before do
    queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
  end

  context "block raises an exception" do
    before do
      expect { queue.process_one do |op, type, ids| raise E end }.to raise_error(E)
    end

    it "reraises the exception" do
      # checked in before block
    end

    it "keeps the item in the queue" do
      expect(items.map(&:entity_id)).to contain_exactly(12)
    end

    it "increments the failed_attempt count" do
      expect(items.map(&:failed_attempts)).to contain_exactly(1)
    end
  end

  context "block returns false" do
    before do
      @result = queue.process_one do |op, type, ids| false end
    end

    it "returns false" do
      expect(@result).to be false
    end

    it "keeps the item in the queue" do
      expect(items.map(&:entity_id)).to contain_exactly(12)
    end

    it "increments the failed_attempt count" do
      expect(items.map(&:failed_attempts)).to contain_exactly(1)
    end
  end

  context "failed_attempts reached MAX_ATTEMPTS" do
    before do
      expect(Postqueue::MAX_ATTEMPTS).to be >= 3
      items.update_all(failed_attempts: Postqueue::MAX_ATTEMPTS)

      @called_block = 0
      @result = queue.process_one do called_block += 1; false end
    end

    it "does not call the block" do
      expect(@called_block).to eq(0)
    end

    it "returns nil" do
      expect(@result).to eq(nil)
    end

    it "does not remove the item" do
      expect(items.map(&:entity_id)).to contain_exactly(12)
    end

    it "does not increment the failed_attempts count" do
      expect(items.first.failed_attempts).to eq(Postqueue::MAX_ATTEMPTS)
    end
  end
end
