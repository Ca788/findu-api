# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Category::PurgeCategoryWithoutInstallmentsUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let(:category) { create(:financial_category, user: user) }
  let(:plan) { create(:financial_installment_plan, user: user, category: category, total_installments: 2) }

  def open_installment(number: 1)
    create(
      :financial_transaction,
      :pending,
      :expense,
      user: user,
      category: category,
      installment_plan: plan,
      installment_number: number,
      competency_month: Date.current.beginning_of_month
    )
  end

  describe "when the last open installment is paid" do
    it "deletes the category" do
      installment = open_installment

      expect {
        UseCase::Financial::Statements::MarkPaidUseCase.new.call(user: user, id: installment.id)
      }.to change(user.categories, :count).by(-1)

      expect(installment.reload.category_id).to be_nil
    end
  end

  describe "when another installment is still open" do
    it "keeps the category" do
      first = open_installment(number: 1)
      open_installment(number: 2)

      expect {
        UseCase::Financial::Statements::MarkPaidUseCase.new.call(user: user, id: first.id)
      }.not_to change(user.categories, :count)
    end
  end

  describe "when the category also has a regular transaction" do
    it "keeps the category after the installment is paid" do
      installment = open_installment
      create(:financial_transaction, :expense, user: user, category: category)

      UseCase::Financial::Statements::MarkPaidUseCase.new.call(user: user, id: installment.id)

      expect(Financial::Category.exists?(category.id)).to be(true)
    end
  end

  describe "when an installment plan is canceled" do
    it "deletes the category if no other activity remains" do
      open_installment

      expect {
        UseCase::Financial::InstallmentPlan::CancelInstallmentPlanUseCase.new.call(user: user, id: plan.id)
      }.to change(user.categories, :count).by(-1)
    end
  end

  describe "when the plan moves to another category" do
    it "deletes the previous category if it is left without installments" do
      open_installment
      other = create(:financial_category, user: user, name: "Outra")

      UseCase::Financial::InstallmentPlan::UpdateInstallmentPlanUseCase.new.call(
        user: user,
        id: plan.id,
        attributes: { category_id: other.id }
      )

      expect(Financial::Category.exists?(category.id)).to be(false)
      expect(plan.reload.category_id).to eq(other.id)
    end
  end

  describe "when the category was never used by an installment" do
    it "does not auto-delete an empty category" do
      category

      expect {
        use_case.call(user: user, category_ids: category.id)
      }.not_to change(user.categories, :count)
    end
  end
end
