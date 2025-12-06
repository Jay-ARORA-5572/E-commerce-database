# E-Commerce Database Project (MySQL)

This repository contains a production-ready relational database schema for an e-commerce website, implemented for MySQL.  
Files in this package:
- `ecommerce_db.sql` — complete SQL: schema, demo data, triggers, stored procedure.
- `ER_diagram.dot` — Graphviz DOT source for the ER diagram.
- `ER_diagram.png` and `ER_diagram.svg` — rendered diagram (if available).
- `README.md` — this file.

## How to import locally (MySQL Workbench)
1. Open MySQL Workbench and connect to your local MySQL server.
2. Open `ecommerce_db.sql` (File → Open SQL Script).
3. Execute the whole script (click the lightning bolt or press Ctrl+Shift+Enter).
4. Verify tables:
   ```sql
   USE ecommerce_db;
   SHOW TABLES;
   ```
5. Test queries provided in the earlier documentation.

## How to run the stored procedure example
```sql
CALL place_order_from_cart(2, 1, 'credit_card', @order_id);
SELECT @order_id;
```

## Notes
- Passwords in demo are placeholders. Use bcrypt on application side and store hashes.
- Test triggers and procedures on a development database first.

