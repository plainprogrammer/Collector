require "rails_helper"

# Spec 044 AC-1.1, ADR 0026: a form builder field comes out as written when its record has an error. Rails calls
# field_error_proc with instance_exec only when the attribute has errors, so this renders a form instead of calling the
# proc: a config key Rails never applied would pass a direct call and fail here.
RSpec.describe "The form builder's field errors" do
  before do
    stub_const("FieldErrorProbe", Class.new do
      include ActiveModel::Model

      attr_accessor :name
    end)
  end

  def render_form(record)
    ApplicationController.render(layout: false, locals: { record: }, inline: <<~ERB)
      <%= form_with model: record, url: "/" do |form| %>
        <%= form.label :name %>
        <%= form.text_field :name %>
      <% end %>
    ERB
  end

  def parse(markup) = Nokogiri::HTML5.fragment(markup)

  let(:plain) { parse(render_form(FieldErrorProbe.new)) }
  let(:invalid) do
    record = FieldErrorProbe.new
    record.errors.add(:name, "can't be blank")
    parse(render_form(record))
  end

  it "wraps nothing when an attribute has an error", :aggregate_failures do
    expect(plain.css(".field_with_errors")).to be_empty # the template itself holds no wrapper
    expect(invalid.css(".field_with_errors")).to be_empty
    expect(invalid.at_css("form").element_children.map(&:name)).to eq(%w[label input])
  end

  it "writes the form's label and input exactly as it does without the error" do
    expect(invalid.at_css("form").inner_html.squish).to eq(plain.at_css("form").inner_html.squish)
  end
end
