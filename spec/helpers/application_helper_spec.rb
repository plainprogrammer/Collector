require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#field_error_ids" do
    it "gives every message its own id" do
      expect(helper.field_error_ids("email-error", [ "a", "b", "c" ])).to eq(%w[email-error email-error-2 email-error-3])
    end
  end

  describe "#field_error_describedby" do
    it "lists every message id" do
      expect(helper.field_error_describedby("email-error", [ "a", "b" ])).to eq("email-error email-error-2")
    end

    it "is nil when the field is valid" do
      expect(helper.field_error_describedby("email-error", [])).to be_nil
    end
  end
end
