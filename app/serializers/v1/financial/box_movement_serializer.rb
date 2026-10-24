# frozen_string_literal: true

module V1
  module Financial
    class BoxMovementSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :box_id, :kind, :source, :amount, :balance_after, :description, :occurred_at, :transaction_id
      end

      view :extended do
        include_view :default
        fields :created_at
      end
    end
  end
end
