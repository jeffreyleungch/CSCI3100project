class ItemsController < ApplicationController
  def index
    @items = Item.all
    filter_params = params.slice(:category, :min_price, :max_price)
    @items = @items.where(filter_params) if filter_params.values.any?
    @items = @items.order(params[:sort_by]) if params[:sort_by].present?
  end

  def show
    @item = Item.find(params[:id])
  end

  def search
    search_term = params[:query]
    @items = Item.where('MATCH(name, description) AGAINST(?)', search_term)
  end
end