# frozen_string_literal: true

module V1
  module Financial
    class InvestmentSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :name, :asset_type, :institution, :invested_amount, :current_amount,
               :invested_on, :status
        field(:return_amount)  { |investment| investment.return_amount }
        field(:return_percent) { |investment| investment.return_percent }
      end

      view :extended do
        include_view :default
        fields :notes, :created_at, :updated_at
      end
    end
  end
end
