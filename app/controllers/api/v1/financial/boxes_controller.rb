# frozen_string_literal: true

module Api
  module V1
    module Financial
      class BoxesController < Api::BaseController
        def index
          boxes = UseCase::Financial::Box::ListBoxesUseCase.new.call(
            user:     @user,
            kind:     params[:kind],
            archived: ActiveModel::Type::Boolean.new.cast(params[:archived]) || false
          ).page(page_param).per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            boxes,
            serializer:      ::V1::Financial::BoxSerializer,
            serializer_view: serializer_view_param,
            pagination:      pagination_for(boxes),
            metadata:        { illustration_keys: ::Financial::Box::ILLUSTRATION_KEYS, kinds: ::Financial::Box::KINDS.values }
          ), status: :ok
        end

        def show
          box = @user.boxes.find(params[:id])

          render json: ApiResponseSerializer.render(
            box,
            serializer:      ::V1::Financial::BoxSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          box = UseCase::Financial::Box::CreateBoxUseCase.new.call(
            user:            @user,
            attributes:      box_params.to_h,
            initial_balance: params.dig(:box, :initial_balance)
          )

          render json: ApiResponseSerializer.render(
            box,
            serializer:      ::V1::Financial::BoxSerializer,
            serializer_view: :extended,
            message:         "Box created successfully."
          ), status: :created
        end

        def update
          box = UseCase::Financial::Box::UpdateBoxUseCase.new.call(
            user:       @user,
            id:         params[:id],
            attributes: box_params.to_h
          )

          render json: ApiResponseSerializer.render(
            box,
            serializer:      ::V1::Financial::BoxSerializer,
            serializer_view: :extended,
            message:         "Box updated successfully."
          ), status: :ok
        end

        def archive
          box = UseCase::Financial::Box::ArchiveBoxUseCase.new.call(
            user:     @user,
            id:       params[:id],
            archived: !ActiveModel::Type::Boolean.new.cast(params[:restore])
          )

          render json: ApiResponseSerializer.render(
            box,
            serializer:      ::V1::Financial::BoxSerializer,
            serializer_view: :extended,
            message:         box.archived? ? "Box archived." : "Box restored."
          ), status: :ok
        end

        def move
          result = UseCase::Financial::Box::MoveBoxFundsUseCase.new.call(
            user:        @user,
            id:          params[:id],
            kind:        movement_params[:kind],
            amount:      movement_params[:amount],
            description: movement_params[:description],
            occurred_at: movement_params[:occurred_at]
          )

          render json: ApiResponseSerializer.render(
            {
              box:      ::V1::Financial::BoxSerializer.render_as_hash(result.box, view: :extended),
              movement: ::V1::Financial::BoxMovementSerializer.render_as_hash(result.movement, view: :extended)
            },
            message: "Movement registered."
          ), status: :created
        end

        private

        def box_params
          params.require(:box).permit(*::Financial::Box::PERMITTED_ATTRIBUTES)
        end

        def movement_params
          params.require(:movement).permit(:kind, :amount, :description, :occurred_at)
        end
      end
    end
  end
end
