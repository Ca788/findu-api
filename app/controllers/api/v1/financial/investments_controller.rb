# frozen_string_literal: true

module Api
  module V1
    module Financial
      class InvestmentsController < Api::BaseController
        def index
          investments = UseCase::Financial::Investment::ListInvestmentsUseCase.new.call(
            user:       @user,
            status:     params[:status],
            asset_type: params[:asset_type]
          ).page(page_param).per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            investments,
            serializer:      ::V1::Financial::InvestmentSerializer,
            serializer_view: serializer_view_param,
            pagination:      pagination_for(investments)
          ), status: :ok
        end

        def show
          investment = @user.investments.find(params[:id])

          render json: ApiResponseSerializer.render(
            investment,
            serializer:      ::V1::Financial::InvestmentSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          investment = UseCase::Financial::Investment::CreateInvestmentUseCase.new.call(
            user:       @user,
            attributes: investment_params.to_h
          )

          render json: ApiResponseSerializer.render(
            investment,
            serializer:      ::V1::Financial::InvestmentSerializer,
            serializer_view: :extended,
            message:         "Investment created successfully."
          ), status: :created
        end

        def update
          investment = UseCase::Financial::Investment::UpdateInvestmentUseCase.new.call(
            user:       @user,
            id:         params[:id],
            attributes: investment_params.to_h
          )

          render json: ApiResponseSerializer.render(
            investment,
            serializer:      ::V1::Financial::InvestmentSerializer,
            serializer_view: :extended,
            message:         "Investment updated successfully."
          ), status: :ok
        end

        def destroy
          @user.investments.find(params[:id]).destroy!

          render json: ApiResponseSerializer.render(
            {},
            message: "Investment deleted successfully."
          ), status: :ok
        end

        private

        def investment_params
          params.require(:investment).permit(*::Financial::Investment::PERMITTED_ATTRIBUTES)
        end
      end
    end
  end
end
