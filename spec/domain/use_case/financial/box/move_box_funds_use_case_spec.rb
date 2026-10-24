# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Box::MoveBoxFundsUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let(:box)  { create(:financial_box, user: user) }

  describe "#call" do
    it "deposits and records balance_after" do
      result = use_case.call(user: user, id: box.id, kind: "deposit", amount: 150.5)

      expect(result.box.balance).to eq(150.5)
      expect(result.movement).to have_attributes(kind: "deposit", amount: 150.5, balance_after: 150.5, source: "manual")
    end

    it "withdraws without going negative" do
      use_case.call(user: user, id: box.id, kind: "deposit", amount: 100)
      result = use_case.call(user: user, id: box.id, kind: "withdraw", amount: 40)

      expect(result.box.balance).to eq(60)
      expect(result.movement.amount).to eq(-40)

      expect {
        use_case.call(user: user, id: box.id, kind: "withdraw", amount: 100)
      }.to raise_error(described_class::InsufficientFunds)
      expect(box.reload.balance).to eq(60)
    end

    it "adjusts to a target balance generating the delta" do
      use_case.call(user: user, id: box.id, kind: "deposit", amount: 100)
      result = use_case.call(user: user, id: box.id, kind: "adjustment", amount: 250)

      expect(result.box.balance).to eq(250)
      expect(result.movement.amount).to eq(150)
    end

    it "rejects non-positive deposits and unknown kinds" do
      expect { use_case.call(user: user, id: box.id, kind: "deposit", amount: 0) }.to raise_error(ArgumentError)
      expect { use_case.call(user: user, id: box.id, kind: "transfer", amount: 1) }.to raise_error(ArgumentError)
    end

    it "is scoped to the owner and ignores archived boxes" do
      other = create(:user)
      expect { use_case.call(user: other, id: box.id, kind: "deposit", amount: 1) }
        .to raise_error(ActiveRecord::RecordNotFound)

      box.update!(archived_at: Time.current)
      expect { use_case.call(user: user, id: box.id, kind: "deposit", amount: 1) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end

    it "keeps the ledger consistent with the cached balance" do
      [30, 20, -10, 5].each do |value|
        use_case.call(user: user, id: box.id, kind: value.positive? ? "deposit" : "withdraw", amount: value.abs)
      end

      expect(box.reload.balance).to eq(45)
      expect(box.movements.sum(:amount)).to eq(box.balance)
      expect(box.movements.recent.first.balance_after).to eq(box.balance)
    end
  end
end
