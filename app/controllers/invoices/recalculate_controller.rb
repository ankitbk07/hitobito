# frozen_string_literal: true

#  Copyright (c) 2022, Schweizer Wanderwege. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class Invoices::RecalculateController < ApplicationController
  respond_to :js
  before_action :authorize_action
  helper_method :entry

  def new
  end

  private

  def entry
    @entry ||= build_entry
  end

  def build_entry
    invoice = Invoice.new

    invoice.attributes = permitted_params

    invoice.group = group
    invoice
  end

  def permitted_params
    invoice_params = params.dig(:invoice_list, :invoice) || params[:invoice]
    permitted_params = invoice_params ? invoice_params.permit(InvoicesController.permitted_attrs) : {}

    permitted_params[:invoice_items_attributes]&.each_value { |item| item.delete("id") }

    permitted_params
  end

  def group
    @group ||= Group.find(params[:group_id])
  end

  def authorize_action
    authorize!(:index_invoices, group)
  end
end
