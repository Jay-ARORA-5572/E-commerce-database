-- declare variable to receive order id
CALL place_order_from_cart(2, 1, 'credit_card', @order_id);
SELECT @order_id;
