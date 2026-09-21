# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::Directory, :default_creates do
  subject(:directory) { described_class.new(scope: User.all, **filters) }

  let!(:searchable) { create(:teacher, school: school, forename: "Ada", surname: "Lovelace", username: "alovelace") }
  let!(:other) { create(:student, school: school, forename: "Grace", surname: "Hopper", username: "ghopper") }

  context "with no filters" do
    let(:filters) { {} }

    it "returns every user in surname order" do
      expect(directory.users.to_a).to start_with(other, searchable)
    end
  end

  context "with a search term" do
    let(:filters) { {search: "lovel"} }

    it "matches on surname" do
      expect(directory.users).to contain_exactly(searchable)
    end
  end

  context "with a username search term" do
    let(:filters) { {search: "ghopp"} }

    it "matches on username" do
      expect(directory.users).to contain_exactly(other)
    end
  end

  context "with a type filter" do
    let(:filters) { {type: "employee"} }

    it "returns only users of that type" do
      expect(directory.users).to contain_exactly(searchable)
    end
  end

  context "with a role filter" do
    let(:filters) { {role: "lesson_author"} }

    before { searchable.add_role(:lesson_author, quiz_subject) }

    it "returns only users holding that role" do
      expect(directory.users).to contain_exactly(searchable)
    end
  end

  context "with a school filter" do
    let(:filters) { {school: other_school.id} }
    let(:other_school) { create(:school) }
    let!(:elsewhere) { create(:student, school: other_school) }

    it "returns only that school's users" do
      expect(directory.users).to contain_exactly(elsewhere)
    end
  end
end
