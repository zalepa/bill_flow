require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  test "status is one of draft/sent/paid/overdue" do
    invoice = Invoice.new(
      client: clients(:acme),
      number: 1001,
      issued_on: Date.today,
      due_on: Date.today + 30,
      notes: "Test invoice"
    )

    invoice.status = :draft
    assert invoice.valid?
    assert invoice.draft?

    invoice.status = :sent
    assert invoice.valid?
    assert invoice.sent?

    invoice.status = :paid
    assert invoice.valid?
    assert invoice.paid?

    invoice.status = :overdue
    assert invoice.valid?
    assert invoice.overdue?

    invoice.draft!
    assert invoice.draft?

    invoice.sent!
    assert invoice.sent?

    invoice.paid!
    assert invoice.paid?

    invoice.overdue!
    assert invoice.overdue?

    assert_raises(ArgumentError) do
      invoice.status = 99 # invalid status
    end
  end

  test "requires a client" do
    invoice = Invoice.new(
      number: 1002,
      status: :draft,
      issued_on: Date.today,
      due_on: Date.today + 30,
      notes: "Test invoice without client"
    )
    assert_not invoice.valid?
    assert_includes invoice.errors[:client], "must exist"
  end

  test "requires a number" do
    invoice = Invoice.new(
      client: clients(:acme),
      status: :draft,
      issued_on: Date.today,
      due_on: Date.today + 30,
      notes: "Test invoice without number"
    )
    assert_not invoice.valid?
    assert_includes invoice.errors[:number], "can't be blank"
  end

  test "requires a unique number for a given client" do
    existing_invoice = invoices(:good)
    invoice = Invoice.new(
      client: existing_invoice.client,
      number: existing_invoice.number,
      status: :draft,
      issued_on: Date.today,
      due_on: Date.today + 30,
      notes: "Test invoice with duplicate number"
    )
    assert_not invoice.valid?
    assert_includes invoice.errors[:number], "has already been taken"

    other_client = clients(:globex)
    invoice.client = other_client
    assert invoice.valid?
  end

  test "due date must be after invoice data" do
    invoice = Invoice.new(
      client: clients(:acme),
      number: 1003,
      status: :draft,
      issued_on: Date.today,
      due_on: Date.today - 1,
      notes: "Test invoice with invalid due date"
    )
    assert_not invoice.valid?
    assert_includes invoice.errors[:due_on], "must be after issued on date"

    invoice.due_on = Date.today + 30
    assert invoice.valid?
  end

  test "due date can be blank for drafts but must be present for sent/paid/overdue invoices" do
    invoice = Invoice.new(
      client: clients(:acme),
      number: 1004,
      status: :draft,
      issued_on: Date.today,
      due_on: nil,
      notes: "Test draft invoice with blank due date"
    )

    assert invoice.valid?

    invoice.due_on = Date.today + 30

    invoice.sent!

    invoice.due_on = nil
    assert_not invoice.valid?
    assert_includes invoice.errors[:due_on], "can't be blank"

    invoice.due_on = Date.today + 30
    assert invoice.valid?
  end

  test "invoice date can be blank for drafts but must be present for sent/paid/overdue invoices" do
    invoice = Invoice.new(
      client: clients(:acme),
      number: 1004,
      status: :draft,
      issued_on: nil,
      due_on: Date.today + 30,
      notes: "Test draft invoice with blank due date"
    )

    assert invoice.valid?

    invoice.issued_on = Date.today

    invoice.sent!

    invoice.issued_on = nil
    assert_not invoice.valid?
    assert_includes invoice.errors[:issued_on], "can't be blank"

    invoice.issued_on = Date.today
    assert invoice.valid?
  end

  test "an invoice can have one or more line items" do
    invoice = invoices(:good)
    invoice.line_items.destroy_all

    invoice.line_items.create(description: "Item 1", quantity: 1, unit_price: 100)
    assert_equal 1, invoice.line_items.count

    invoice.line_items.create(description: "Item 2", quantity: 2, unit_price: 200)
    assert_equal 2, invoice.line_items.count
  end

  test "destroying an invoice destroys associated line items" do
    invoice = invoices(:good)

    invoice.line_items.destroy_all

    invoice.line_items.create(description: "Item 1", quantity: 1, unit_price: 100)

    assert_difference [ "Invoice.count", "LineItem.count" ], -1 do
      invoice.destroy
    end
  end

  test "#total returns the total amount of line items" do
    invoice = invoices(:good)
    invoice.line_items.destroy_all

    assert_equal 0, invoice.total

    invoice.line_items.create(description: "Item 1", quantity: 2, unit_price: 100) # 200
    invoice.line_items.create(description: "Item 2", quantity: 3, unit_price: 150) # 450

    assert_equal 650, invoice.total
  end

  test "#generate_number generates a unique invoice number for a client" do
    client = clients(:acme)
    existing_numbers = client.invoices.pluck(:number)

    new_invoice = Invoice.new(client: client)
    new_invoice.generate_number

    assert_not_includes existing_numbers, new_invoice.number

    new_invoice.save

    another_invoice = Invoice.new(client: client)
    another_invoice.generate_number
    assert_not_equal new_invoice.number, another_invoice.number
    assert_not_includes existing_numbers, another_invoice.number
  end

  test "overdue scope returns invoices past due date and not paid" do
    invoice = invoices(:good)
    invoice.issued_on = Date.today - 60
    invoice.due_on = Date.today - 1
    invoice.status = :overdue
    invoice.save!

    assert_equal 1, Invoice.overdue.count

    # Test malformed entry
    invoice.status = :sent
    invoice.issued_on = Date.today - 60
    invoice.due_on = Date.today - 1
    invoice.save!
    assert_equal 1, Invoice.overdue.count
  end
end
