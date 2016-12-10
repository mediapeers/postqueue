require 'spec_helper'

describe "Idempotent queue" do
  class Testqueue < Postqueue::Base
    def idempotent?(entity_type:,op:)
      true
    end

    def batch_size(entity_type:,op:)
      100
    end
  end

  let(:queue) { Testqueue.new }

  context 'when having entries with the same entity_type and op' do
    before do
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 13
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 14
    end

    it "processes one entries" do
      r = queue.process batch_size: 1
      expect(r).to eq(["myop", "mytype", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13, 14)
    end

    it "processes two entries" do
      r = queue.process batch_size: 2
      expect(r).to eq(["myop", "mytype", [12, 13]])
      expect(items.map(&:entity_id)).to contain_exactly(14)
    end

    it "processes many entries" do
      r = queue.process
      expect(r).to eq(["myop", "mytype", [12, 13, 14]])
      expect(items.map(&:entity_id)).to contain_exactly()
    end
  end

  context 'when having entries with different entity_type and op' do
    before do
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 13
      queue.enqueue op: "otherop", entity_type: "mytype", entity_id: 14
      queue.enqueue op: "myop", entity_type: "othertype", entity_id: 15
      queue.enqueue op: "otherop", entity_type: "othertype", entity_id: 16
    end

    it "processes one entries" do
      r = queue.process batch_size: 1
      expect(r).to eq(["myop", "mytype", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13, 14, 15, 16)
    end

    it "processes two entries" do
      r = queue.process batch_size: 2
      expect(r).to eq(["myop", "mytype", [12, 13]])
      expect(items.map(&:entity_id)).to contain_exactly(14, 15, 16)
    end

    it "processes only matching entries when asked for more" do
      r = queue.process
      expect(r).to eq(["myop", "mytype", [12, 13]])
      expect(items.map(&:entity_id)).to contain_exactly(14, 15, 16)
    end

    it "honors search conditions" do
      r = queue.process(where: { op: "otherop" })
      expect(r).to eq(["otherop", "mytype", [14]])
      expect(items.map(&:entity_id)).to contain_exactly(12, 13, 15, 16)
    end
  end
  
  context 'when having duplicate entries' do
    before do
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 13
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
    end

    it "removes duplicates from the queue" do
      r = queue.process batch_size: 1
      expect(r).to eq(["myop", "mytype", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13)
    end
  end
end
