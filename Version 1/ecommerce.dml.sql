-- =======================================================
-- FILE: dml.sql
-- Script de inserts de datos de prueba (50 filas por tabla),
-- usando un bloque DO con transacción y EXECUTE.
-- =======================================================

DO $$
BEGIN
    RAISE NOTICE 'Iniciando inserción de datos de prueba...';

    BEGIN;  -- Transacción

    /* A continuación, cada INSERT se hace con EXECUTE:
       generamos 50 filas en cada tabla, con valores aleatorios.
       Para simplificar, asumimos que la base (ddl.sql) ya está creada.
    */

    EXECUTE '
    INSERT INTO tenants.tenants (business_name, owner_name, email, password, subscription_plan)
    SELECT
        CONCAT(''EmpresaGT_'', i),
        CONCAT(''PropietarioGT_'', i),
        CONCAT(''empresa'', i, ''@guate.com''),
        CONCAT(''hashpw_'', i),
        CASE WHEN i % 4 = 0 THEN ''ENTERPRISE''
             WHEN i % 3 = 0 THEN ''PREMIUM''
             WHEN i % 2 = 0 THEN ''STANDARD''
             ELSE ''FREE'' END
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO security.users (tenant_id, name, email, password)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''UsuarioGT_'', i),
      CONCAT(''usuario'', i, ''@gtemail.com''),
      CONCAT(''password_'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO security.employees (tenant_id, name, email, password, role)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''EmpleadoGT_'', i),
      CONCAT(''empleado'', i, ''@gtemp.com''),
      CONCAT(''emp_pw_'', i),
      CASE WHEN i % 2 = 0 THEN ''ADMIN'' ELSE ''EMPLOYEE'' END
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO common.country (name, code)
    SELECT
      CONCAT(''Guatemala_'', i),
      CONCAT(''GT'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO common.states (country_id, name, code)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''Depto_'', i),
      CONCAT(''DPT_'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO common.addresses (tenant_id, user_id, address_line1, city, postal_code)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      NULL,
      CONCAT(''Calle '', i, '' Zona '', (1 + floor(random()*25))),
      CONCAT(''Ciudad de Guatemala '', i),
      CONCAT(''010'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO common.phone_numbers (tenant_id, user_id, number)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''+502 55'', (100 + i))
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.taxonomies (tenant_id, name, description)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''TaxonomyGT_'', i),
      CONCAT(''Desc taxonomy '', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.taxons (tenant_id, taxonomy_id, name, description, position)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''TaxonGT_'', i),
      CONCAT(''Desc taxon '', i),
      i
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.items (tenant_id, name, title, description, sku)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''ProductoGT_'', i),
      CONCAT(''Titulo Prod '', i),
      CONCAT(''Descripcion producto #'', i),
      CONCAT(''SKU-GT-'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.item_taxons (item_id, taxon_id)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.variations (tenant_id, item_id, label, variation_sku, price)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''VarLabel_'', i),
      CONCAT(''VAR-SKU-'', i),
      (10 + floor(random()*90))::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.digital_assets (tenant_id, item_id, variation_id, asset_type, asset_url, asset_description)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CASE WHEN i % 2=0 THEN (1 + floor(random()*50))::BIGINT ELSE NULL END,
      CASE WHEN i % 2=1 THEN (1 + floor(random()*50))::BIGINT ELSE NULL END,
      CASE WHEN i % 3=0 THEN ''VIDEO'' WHEN i%3=1 THEN ''IMAGE'' ELSE ''DOCUMENT'' END,
      CONCAT(''http://assets.gt/img_'', i, ''.jpg''),
      CONCAT(''AssetDesc #'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.technical_specifications (tenant_id, item_id, size, material, warranty)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CONCAT((1 + floor(random()*50)), ''cm x '', (1 + floor(random()*50)), ''cm''),
      CONCAT(''Material_'', i),
      CONCAT(''Garantia_'', i, '' meses'')
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.user_review_product (tenant_id, product_id, user_id, rating_count, comment)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*5))::INT,
      CONCAT(''Reseña del user #'', i, ''. Excelente producto'')
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO offers.promotions (tenant_id, name, description, discount_type, discount_value, start_date, end_date)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''PromoGT_'', i),
      CONCAT(''Desc promo #'', i),
      CASE WHEN i % 3=0 THEN ''BUY_X_GET_Y''
           WHEN i % 2=0 THEN ''PERCENTAGE''
           ELSE ''FIXED_AMOUNT'' END,
      (floor(random()*30))::NUMERIC,
      CURRENT_DATE,
      CURRENT_DATE + (floor(random()*10))::INT
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO offers.promotion_product (promotion_id, item_id)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO offers.promotion_taxon (promotion_id, taxon_id)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO offers.promotion_rules (promotion_id, rule_data)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      jsonb_build_object(
        ''min_quantity'', (1 + floor(random()*3)),
        ''max_uses'', (10 + floor(random()*40)),
        ''region'', CONCAT(''GuatemalaZona'', (1 + floor(random()*10)))
      )
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.cart (tenant_id, user_id, expires_at)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      NOW() + ((i % 5)||'' day'')::INTERVAL
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.cart_item (cart_id, item_id, quantity)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*5))
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.order_headers (tenant_id, user_id, shipping_address_id, billing_address_id, total_amount)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (50 + floor(random()*500))::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.order_lines (order_id, item_id, quantity, unit_price, total_price)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*5)),
      (10 + floor(random()*90))::NUMERIC,
      (50 + floor(random()*450))::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.returns (tenant_id, order_id, user_id, item_id, reason, refund_amount)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''Razón de devolución #'', i),
      (10 + floor(random()*40))::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.payment_methods (tenant_id, user_id, method_type, token, masked_number, brand)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CASE WHEN i % 2=0 THEN ''CREDIT_CARD'' ELSE ''PAYPAL'' END,
      CONCAT(''token_'', i),
      CONCAT(''****'', (1000 + i)),
      CASE WHEN i % 3=0 THEN ''VISA'' WHEN i%3=1 THEN ''MASTERCARD'' ELSE ''AMEX'' END
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.payment (tenant_id, user_id, order_id, payment_method_id, transaction_id, amount)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''txn_'', i),
      (50 + floor(random()*400))::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.invoice_headers (tenant_id, order_id, invoice_number, total_amount)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''INV-GT-'', i),
      (100 + floor(random()*900))::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.invoice_lines (invoice_id, description, quantity, unit_price, total_price)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''Detalle Factura '', i),
      (1 + floor(random()*5)),
      (20 + floor(random()*80))::NUMERIC,
      (50 + floor(random()*250))::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO inventory.inventory_location (tenant_id, name, address_id)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      CONCAT(''BodegaGT_'', i),
      (1 + floor(random()*50))::BIGINT
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO inventory.stocks (tenant_id, location_id, item_id, variation_id, quantity)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CASE WHEN i % 2=0 THEN (1 + floor(random()*50))::BIGINT ELSE NULL END,
      CASE WHEN i % 2=1 THEN (1 + floor(random()*50))::BIGINT ELSE NULL END,
      (10 + floor(random()*90))
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO inventory.stock_movements (tenant_id, stock_id, movement_type, quantity, reason)
    SELECT
      (1 + floor(random()*50))::BIGINT,
      (1 + floor(random()*50))::BIGINT,
      CASE WHEN i % 3=0 THEN ''INBOUND'' WHEN i%3=1 THEN ''OUTBOUND'' ELSE ''ADJUST'' END,
      (1 + floor(random()*20)),
      CONCAT(''Movimiento #'', i)
    FROM generate_series(1,50) AS i
    ';

    -- COMMIT si todo salió bien
    COMMIT;

    RAISE NOTICE 'Datos de prueba insertados exitosamente.';

    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'ERROR al insertar datos de prueba. Haciendo ROLLBACK.';
      RAISE NOTICE 'Código de error: %', SQLSTATE;
      RAISE NOTICE 'Mensaje de error: %', SQLERRM;
      ROLLBACK;
    END;

END;
$$ LANGUAGE plpgsql;

-- Fin de dml.sql
