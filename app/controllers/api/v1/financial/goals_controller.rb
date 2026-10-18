# frozen_string_literal: true

module Api
  module V1
    module Financial
      class GoalsController < Api::BaseController
        def index
          goals = UseCase::Financial::Goal::ListGoalsUseCase.new.call(
            user:        @user,
            status:      params[:status],
            category_id: params[:category_id]
          ).page(page_param).per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            goals,
            serializer:      ::V1::Financial::GoalSerializer,
            serializer_view: serializer_view_param,
            pagination:      pagination_for(goals)
          ), status: :ok
        end

        def show
          goal = @user.goals.find(params[:id])

          render json: ApiResponseSerializer.render(
            goal,
            serializer:      ::V1::Financial::GoalSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          goal = UseCase::Financial::Goal::CreateGoalUseCase.new.call(
            user:       @user,
            attributes: goal_params.to_h
          )

          render json: ApiResponseSerializer.render(
            goal,
            serializer:      ::V1::Financial::GoalSerializer,
            serializer_view: :extended,
            message:         "Goal created successfully."
          ), status: :created
        end

        def update
          goal = UseCase::Financial::Goal::UpdateGoalUseCase.new.call(
            user:       @user,
            id:         params[:id],
            attributes: goal_params.to_h
          )

          render json: ApiResponseSerializer.render(
            goal,
            serializer:      ::V1::Financial::GoalSerializer,
            serializer_view: :extended,
            message:         "Goal updated successfully."
          ), status: :ok
        end

        def contribute
          goal = UseCase::Financial::Goal::ContributeToGoalUseCase.new.call(
            user:   @user,
            id:     params[:id],
            amount: contribute_params[:amount]
          )

          render json: ApiResponseSerializer.render(
            goal,
            serializer:      ::V1::Financial::GoalSerializer,
            serializer_view: :extended,
            message:         "Contribution registered successfully."
          ), status: :ok
        end

        def destroy
          @user.goals.find(params[:id]).destroy!

          render json: ApiResponseSerializer.render(
            {},
            message: "Goal deleted successfully."
          ), status: :ok
        end

        private

        def goal_params
          params.require(:goal).permit(*::Financial::Goal::PERMITTED_ATTRIBUTES)
        end

        def contribute_params
          params.require(:contribution).permit(:amount)
        end
      end
    end
  end
end
