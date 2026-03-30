class ItemsController < ApplicationController
  def index
    @items = Item.all
    @item = Item.new
    filter_params = params.slice(:category, :min_price, :max_price)
    @items = @items.where(filter_params) if filter_params.values.any?
    @items = @items.order(params[:sort_by]) if params[:sort_by].present?
  end

  def create
    @item = Item.new(item_params)

    if @item.save
      redirect_to items_path, notice: 'Item created successfully.'
    else
      @items = Item.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @item = Item.find(params[:id])
  end

  def search
    @item = Item.new
    @items = Item.search_by_fulltext(params[:query]).order(created_at: :desc)
    render :index
  end

  private

  def item_params
    params.require(:item).permit(:name, :description, :price, :category, :available)
  end
end