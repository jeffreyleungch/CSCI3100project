module ItemsHelper
  # Formats the price for display
  def format_price(price)
    format('$%.2f', price)
  end

  # Displays the item's name with a maximum length
  def display_item_name(name, max_length = 20)
    name.length > max_length ? name[0...max_length] + '...' : name
  end

  # Formats the date added to a more readable format
  def format_date_added(date)
    date.strftime('%B %d, %Y')
  end
end