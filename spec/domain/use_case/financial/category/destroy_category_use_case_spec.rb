# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Category::DestroyCategoryUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let!(:category) { create(:financial_category, user: user) }

  describe "#call" do
    context "when category belongs to the user" do
      it "destroys the category" do
        expect {
          use_case.call(user: user, id: category.id)
        }.to change(user.categories, :count).by(-1)
      end

      it "returns the destroyed category" do
        result = use_case.call(user: user, id: category.id)

        expect(result.id).to eq(category.id)
        expect(result).to be_destroyed
      end
    end

    context "when category does not belong to the user" do
      let(:other_user) { create(:user) }

      it "raises ActiveRecord::RecordNotFound" do
        expect {
          use_case.call(user: other_user, id: category.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not destroy the category" do
        expect {
          begin
            use_case.call(user: other_user, id: category.id)
          rescue ActiveRecord::RecordNotFound
            nil
          end
        }.not_to change(Financial::Category, :count)
      end
    end

    context "when category does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          use_case.call(user: user, id: SecureRandom.uuid)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when category has associated transactions" do
      before do
        create(:financial_transaction, user: user, category: category)
      end

      it "raises ArgumentError" do
        expect {
          use_case.call(user: user, id: category.id)
        }.to raise_error(ArgumentError, /associated transactions/)
      end

      it "does not destroy the category" do
        expect {
          begin
            use_case.call(user: user, id: category.id)
          rescue ArgumentError
            nil
          end
        }.not_to change(Financial::Category, :count)
      end
    end

    context "when category still has open installments" do
      let(:plan) { create(:financial_installment_plan, user: user, category: category) }

      before do
        create(:financial_transaction, :pending, user: user, category: category, installment_plan: plan)
      end

      it "raises ArgumentError" do
        expect {
          use_case.call(user: user, id: category.id)
        }.to raise_error(ArgumentError, /remaining installments/)
      end
    end

    context "when only paid installments remain" do
      let(:plan) { create(:financial_installment_plan, user: user, category: category) }
      let!(:installment) do
        create(:financial_transaction, :paid, user: user, category: category, installment_plan: plan)
      end

      it "destroys the category and detaches the history" do
        expect {
          use_case.call(user: user, id: category.id)
        }.to change(user.categories, :count).by(-1)

        expect(installment.reload.category_id).to be_nil
        expect(plan.reload.category_id).to be_nil
      end
    end
  end
end
