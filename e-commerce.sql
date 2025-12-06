
-- ecommerce_db.sql
-- Full schema, demo data, triggers and stored procedure for the e-commerce project

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db;
USE ecommerce_db;

-- Roles
CREATE TABLE roles (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) UNIQUE NOT NULL
);

INSERT INTO roles (role_name) VALUES ('admin'), ('user');

-- Users
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role_id INT NOT NULL,
    phone VARCHAR(15),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES roles(role_id)
);

-- Addresses
CREATE TABLE addresses (
    address_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    city VARCHAR(120),
    state VARCHAR(120),
    country VARCHAR(120),
    pincode VARCHAR(20),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Categories
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(120) NOT NULL UNIQUE,
    description TEXT
);

-- Products
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

-- Product images
CREATE TABLE product_images (
    image_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- Cart
CREATE TABLE cart (
    cart_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Cart items
CREATE TABLE cart_items (
    cart_item_id INT AUTO_INCREMENT PRIMARY KEY,
    cart_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    FOREIGN KEY (cart_id) REFERENCES cart(cart_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Orders
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    address_id INT NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (address_id) REFERENCES addresses(address_id)
);

-- Order items
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price_at_purchase DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Payments
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    method VARCHAR(50),
    payment_status VARCHAR(50) DEFAULT 'pending',
    paid_at TIMESTAMP NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- Sample demo data
INSERT INTO users (full_name, email, password_hash, role_id, phone)
VALUES
  ('Alice Admin', 'admin@shop.com', 'bcrypt$adminhash', 1, '9991112222'),
  ('John Doe', 'john@example.com', 'bcrypt$userhash', 2, '8881112222'),
  ('Priya Patel', 'priya@example.com', 'bcrypt$userhash2', 2, '7772223333');

INSERT INTO addresses (user_id, line1, line2, city, state, country, pincode)
VALUES
  (2, '12 MG Road', NULL, 'Bengaluru', 'Karnataka', 'India', '560001'),
  (3, 'Flat 10, Green Apartments', 'Near Lake', 'Mumbai', 'Maharashtra', 'India', '400001');

INSERT INTO categories (category_name, description)
VALUES
  ('Electronics', 'Phones, laptops and accessories'),
  ('Clothing', 'Men and Women clothing'),
  ('Home Appliances', 'Devices for home');

INSERT INTO products (category_id, product_name, description, price, stock)
VALUES
  (1, 'iPhone 15', 'Latest model', 79999.00, 20),
  (1, 'Samsung Galaxy S24', 'Flagship Android', 59999.00, 30),
  (2, 'Men Cotton T-Shirt', 'Comfort fit', 699.00, 150),
  (3, 'Automatic Washing Machine', '7kg front load', 24999.00, 10);

INSERT INTO product_images (product_id, image_url)
VALUES
  (1, 'images/iphone15-1.jpg'),
  (1, 'images/iphone15-2.jpg'),
  (2, 'images/galaxy-s24.jpg'),
  (3, 'images/mens-tshirt.jpg');

-- create cart for John (user_id = 2)
INSERT INTO cart (user_id) VALUES (2);
-- assume cart_id = 1 for simplicity in demo

INSERT INTO cart_items (cart_id, product_id, quantity) VALUES
  (1, 1, 1),
  (1, 3, 2);

-- create an order
INSERT INTO orders (user_id, address_id, total_amount, status)
VALUES (2, 1, 81397.00, 'confirmed');

INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase)
VALUES
  (1, 1, 1, 79999.00),
  (1, 3, 2, 699.00);

INSERT INTO payments (order_id, amount, method, payment_status, paid_at)
VALUES (1, 81397.00, 'credit_card', 'paid', NOW());

-- Triggers
DELIMITER $$
CREATE TRIGGER check_stock_before_update
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
  IF NEW.stock < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock cannot be negative';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER after_order_item_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  UPDATE products
    SET stock = stock - NEW.quantity
    WHERE product_id = NEW.product_id;
END$$
DELIMITER ;

-- Stored Procedure: place_order_from_cart
DELIMITER $$
CREATE PROCEDURE place_order_from_cart(
  IN in_user_id INT,
  IN in_address_id INT,
  IN in_payment_method VARCHAR(50),
  OUT out_order_id INT
)
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE v_cart_id INT;
  DECLARE v_product_id INT;
  DECLARE v_qty INT;
  DECLARE v_price DECIMAL(10,2);
  DECLARE v_total DECIMAL(12,2) DEFAULT 0;

  DECLARE cur CURSOR FOR
    SELECT ci.product_id, ci.quantity, p.price
    FROM cart_items ci
    JOIN cart c ON ci.cart_id = c.cart_id
    JOIN products p ON ci.product_id = p.product_id
    WHERE c.user_id = in_user_id;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  START TRANSACTION;

  SELECT cart_id INTO v_cart_id FROM cart WHERE user_id = in_user_id LIMIT 1;
  IF v_cart_id IS NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cart not found for user';
  END IF;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_product_id, v_qty, v_price;
    IF done = 1 THEN
      LEAVE read_loop;
    END IF;
    SET v_total = v_total + (v_qty * v_price);
  END LOOP;
  CLOSE cur;

  IF v_total = 0 THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cart is empty';
  END IF;

  INSERT INTO orders (user_id, address_id, total_amount, status)
  VALUES (in_user_id, in_address_id, v_total, 'pending');

  SET out_order_id = LAST_INSERT_ID();

  INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase)
  SELECT out_order_id, ci.product_id, ci.quantity, p.price
  FROM cart_items ci
  JOIN cart c ON ci.cart_id = c.cart_id
  JOIN products p ON ci.product_id = p.product_id
  WHERE c.user_id = in_user_id;

  UPDATE products p
  JOIN (
    SELECT ci.product_id, SUM(ci.quantity) AS qty
    FROM cart_items ci
    JOIN cart c ON ci.cart_id = c.cart_id
    WHERE c.user_id = in_user_id
    GROUP BY ci.product_id
  ) AS summary ON p.product_id = summary.product_id
  SET p.stock = p.stock - summary.qty;

  INSERT INTO payments (order_id, amount, method, payment_status, paid_at)
  VALUES (out_order_id, v_total, in_payment_method, 'pending', NULL);

  DELETE ci FROM cart_items ci
  JOIN cart c ON ci.cart_id = c.cart_id
  WHERE c.user_id = in_user_id;

  COMMIT;
END$$
DELIMITER ;
