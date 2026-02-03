require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  test "it requires an invoice" do
    line_item = LineItem.new(description: "Test Item", quantity: 2, unit_price: 500)
    assert_not line_item.valid?
    assert_includes line_item.errors[:invoice], "must exist"
  end

  test "it requires a description" do
    line_item = line_items(:web)
    line_item.description = nil
    assert_not line_item.valid?
    assert_includes line_item.errors[:description], "can't be blank"
  end

  test "it has default quantity and unit price" do
    invoice = invoices(:good)
    line_item = LineItem.new(description: "Test Item", invoice: invoice)
    assert_equal 1, line_item.quantity
    assert_equal 0, line_item.unit_price
  end

  test "it requires a quantity" do
    line_item = line_items(:web)
    line_item.quantity = nil
    assert_not line_item.valid?
    assert_includes line_item.errors[:quantity], "can't be blank"
  end

  test "it requires a quantity greater than zero" do
    line_item = line_items(:web)
    line_item.quantity = 0
    assert_not line_item.valid?
    assert_includes line_item.errors[:quantity], "must be greater than 0"

    line_item.quantity = -1
    assert_not line_item.valid?
    assert_includes line_item.errors[:quantity], "must be greater than 0"
  end

  test "it requires a unit price" do
    line_item = line_items(:web)
    line_item.unit_price = nil
    assert_not line_item.valid?
    assert_includes line_item.errors[:unit_price], "is not a number"
  end

  test "it requires a unit price greater than or equal to zero" do
    line_item = line_items(:web)
    line_item.unit_price = 0
    assert line_item.valid?

    line_item.unit_price = -1
    assert_not line_item.valid?
    assert_includes line_item.errors[:unit_price], "must be greater than or equal to 0"
  end
end
