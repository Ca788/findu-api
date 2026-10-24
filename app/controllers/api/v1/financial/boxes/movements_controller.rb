# frozen_string_literal: true

module Api
  module V1
    module Financial
      module Boxes
        class MovementsController < Api::BaseController
          def index
            box = @user.boxes.find(params[:box_id])
            movements = box.movements.recent.page(page_param).per(per_page_param)

            render json: ApiResponseSerializer.render_data_array(
              movements,
              serializer:      ::V1::Financial::BoxMovementSerializer,
              serializer_view: serializer_view_param,
              pagination:      pagination_for(movements)
            ), status: :ok
          end
        end
      end
    end
  end
end
