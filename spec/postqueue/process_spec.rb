require 'spec_helper'

describe "::Postqueue.process" do
  context 'when having entries with the same entity_type and op' do
    before do
      Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
      Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 13
      Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 14
    end

    it "processes one entries" do
      r = Postqueue.process batch_size: 1
      expect(r).to eq(["myop", "mytype", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13, 14)
    end

    it "processes two entries" do
      r = Postqueue.process batch_size: 2
      expect(r).to eq(["myop", "mytype", [12, 13]])
      expect(items.map(&:entity_id)).to contain_exactly(14)
    end

    it "processes many entries" do
      r = Postqueue.process
      expect(r).to eq(["myop", "mytype", [12, 13, 14]])
      expect(items.map(&:entity_id)).to contain_exactly()
    end
  end

  context 'when having entries with different entity_type and op' do
    before do
      Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
      Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 13
      Postqueue.enqueue op: "otherop", entity_type: "mytype", entity_id: 14
      Postqueue.enqueue op: "myop", entity_type: "othertype", entity_id: 15
      Postqueue.enqueue op: "otherop", entity_type: "othertype", entity_id: 16
    end

    it "processes one entries" do
      r = Postqueue.process batch_size: 1
      expect(r).to eq(["myop", "mytype", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13, 14, 15, 16)
    end

    it "processes two entries" do
      r = Postqueue.process batch_size: 2
      expect(r).to eq(["myop", "mytype", [12, 13]])
      expect(items.map(&:entity_id)).to contain_exactly(14, 15, 16)
    end

    it "processes only matching entries when asked for more" do
      r = Postqueue.process
      expect(r).to eq(["myop", "mytype", [12, 13]])
      expect(items.map(&:entity_id)).to contain_exactly(14, 15, 16)
    end

    it "honors search conditions" do
      r = Postqueue.process(where: { op: "otherop" })
      expect(r).to eq(["otherop", "mytype", [14]])
      expect(items.map(&:entity_id)).to contain_exactly(12, 13, 15, 16)
    end
  end
  
  context 'when having duplicate entries' do
    before do
      Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
      Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 13
      Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
    end

    it "removes duplicates from the queue" do
      r = Postqueue.process batch_size: 1
      expect(r).to eq(["myop", "mytype", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13)
    end

    it "does not remove duplicates when remove_duplicates is set to false" do
      r = Postqueue.process batch_size: 1, remove_duplicates: false
      expect(r).to eq(["myop", "mytype", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13, 12)
    end
  end
end
