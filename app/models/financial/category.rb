# == Schema Information
#
# Table name: categories
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  whatsapp   :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_categories_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Category < ApplicationRecord
    belongs_to :user

    has_many :transactions, class_name: "Financial::Transaction", dependent: :nullify
    has_many :receipts, class_name: "Financial::Receipt", dependent: :nullify
    has_many :installment_plans, class_name: "Financial::InstallmentPlan", dependent: :nullify
    has_many :recurrence_rules, class_name: "Financial::RecurrenceRule", dependent: :nullify
    has_many :goals, class_name: "Financial::Goal", dependent: :nullify

    validates :name, presence: true
    validates :whatsapp, format: { with: /\A\+?\d{8,15}\z/ }, allow_blank: true

    before_validation :normalize_whatsapp

    # Parcelas de parcelamento ainda em aberto.
    # @return [Boolean]
    def pending_installments?
      transactions.pending.where.not(installment_plan_id: nil).exists?
    end

    # Lançamentos ou recorrências que não fazem parte de um parcelamento.
    # @return [Boolean]
    def standalone_activity?
      transactions.where(installment_plan_id: nil).exists? || recurrence_rules.exists?
    end

    # @return [Boolean]
    def installment_backed?
      installment_plans.exists? || transactions.where.not(installment_plan_id: nil).exists?
    end

    # Categoria que só existia por causa de parcelamento e não tem mais parcelas em aberto.
    # @return [Boolean]
    def auto_releasable?
      installment_backed? && !pending_installments? && !standalone_activity?
    end

    # Remove a categoria quando não restam parcelas em aberto e não há outra atividade.
    # `orphaned` cobre o caso em que o plano mudou de categoria e esta ficou vazia.
    #
    # @param [User] user
    # @param [String] category_id
    # @param [Boolean] orphaned
    # @return [Financial::Category, nil]
    def self.release_without_pending_installments!(user:, category_id:, orphaned: false)
      return if user.nil? || category_id.blank?

      category = user.categories.find_by(id: category_id)
      return if category.nil?
      return if category.pending_installments?
      return if category.standalone_activity?
      return unless orphaned || category.installment_backed?

      category.destroy!
      category
    end

    private

    def normalize_whatsapp
      return if whatsapp.blank?

      self.whatsapp = Support::Phone.e164(whatsapp)
    end
  end
end
