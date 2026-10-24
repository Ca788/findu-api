# frozen_string_literal: true

module V1
  module Financial
    class BoxSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :name, :kind, :illustration_key, :color, :target_amount, :balance, :position
        field(:remaining_amount) { |box| box.remaining_amount }
        field(:progress_percent) { |box| box.progress_percent }
        field(:archived)         { |box| box.archived? }
      end

      view :extended do
        include_view :default
        fields :notes, :archived_at, :created_at, :updated_at
      end
    end
  end
end
