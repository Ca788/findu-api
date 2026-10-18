# frozen_string_literal: true

module V1
  module Financial
    class GoalSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :name, :target_amount, :current_amount, :deadline, :status, :category_id
        field(:remaining_amount)  { |goal| goal.remaining_amount }
        field(:progress_percent)  { |goal| goal.progress_percent }
      end

      view :extended do
        include_view :default
        fields :notes, :achieved_at, :created_at, :updated_at

        association :category, blueprint: V1::Financial::CategorySerializer, view: :default
      end
    end
  end
end
