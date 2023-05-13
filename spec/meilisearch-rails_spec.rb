require 'spec_helper'

class MongoidCustomPrimaryKeyTestModel
  include Mongoid::Document
  include MeiliSearch::Rails
  meilisearch primary_key: :ms_id
  field :title, type: String

  def ms_id
    # note for folks unfamiliar with mongo.
    # there _will_ be an _id even if it isn't persisted
    "mongoid_custom_primary_key_test_#{_id.to_s}"
  end
end

RSpec.describe MeiliSearch::Rails do
  context "Mongoid" do
    before do
      allow(described_class).to(receive(:_mongoid?).and_return(true))
      # allow(:defined?).to(
      #   receive(::Mongoid::Document)
      #     .and_return(true))
      # allow(described_class).to(
      #   receive(:include?).with(::Mongoid::Document)
      #     .and_return(true)
      # )
    end
    it "should return a primary key method of _id" do
      expect(described_class.ms_primary_key_method).to(eq(:_id))
    end
    context "when using a custom primary key" do
      let(:test_model){MongoidCustomPrimaryKeyTestModel.new(title: 'foo')}
      it "should find custom primary key method" do
        expect(test_model.ms_primary_key_method).to(eq(:ms_id))
      end
    end

  end
  context "Relational" do

  end

end
