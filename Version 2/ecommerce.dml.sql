-- =======================================================
-- FILE: dml.sql
-- Script de inserts de datos de prueba (50 filas por tabla),
-- usando un bloque DO con transacción y EXECUTE,
-- asegurando datos consistentes y casteo a enums.
-- =======================================================

DO $$
BEGIN
    RAISE NOTICE 'Iniciando inserción de datos de prueba...';

    EXECUTE '
    INSERT INTO tenants.tenants (tenant_id, business_name, owner_name, email, password, subscription_plan)
    SELECT
        i,
        CONCAT(''EmpresaGT_'', i),
        CONCAT(''PropietarioGT_'', i),
        CONCAT(''empresa'', i, ''@guate.com''),
        CONCAT(''hashpw_'', i),
        CASE WHEN i % 4 = 0 THEN ''ENTERPRISE''::tenants.plan_type_enum
             WHEN i % 3 = 0 THEN ''PREMIUM''::tenants.plan_type_enum
             WHEN i % 2 = 0 THEN ''STANDARD''::tenants.plan_type_enum
             ELSE ''FREE''::tenants.plan_type_enum
        END
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO security.users (user_id, tenant_id, name, email, password)
    SELECT
        i,
        i,
        CONCAT(''UsuarioGT_'', i),
        CONCAT(''usuario'', i, ''@gtemail.com''),
        CONCAT(''password_'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO security.employees (employee_id, tenant_id, name, email, password, role)
    SELECT
        i,
        i,
        CONCAT(''EmpleadoGT_'', i),
        CONCAT(''empleado'', i, ''@gtemp.com''),
        CONCAT(''emp_pw_'', i),
        CASE WHEN i % 2 = 0 THEN ''ADMIN''::security.role_enum
             ELSE ''EMPLOYEE''::security.role_enum
        END
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO common.country (country_id, name, code)
    SELECT
        i,
        CONCAT(''Guatemala_'', i),
        CONCAT(''GT'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO common.states (state_id, country_id, name, code)
    SELECT
        i,
        i,
        CONCAT(''Depto_'', i),
        CONCAT(''DPT_'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO common.addresses (address_id, tenant_id, user_id, address_line1, city, postal_code)
    SELECT
        i,
        i,
        i,
        CONCAT(''Calle '', i, '' Zona '', i),
        CONCAT(''CiudadDeGuatemala'', i),
        CONCAT(''010'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO common.phone_numbers (phone_id, tenant_id, user_id, number)
    SELECT
        i,
        i,
        i,
        CONCAT(''+502 '', (4000 + i))
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.taxonomies (taxonomy_id, tenant_id, name, description)
    SELECT
        i,
        i,
        CONCAT(''TaxonomyGT_'', i),
        CONCAT(''Desc taxonomy '', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.taxons (taxon_id, tenant_id, taxonomy_id, name, description, position)
    SELECT
        i,
        i,
        i,
        CONCAT(''TaxonGT_'', i),
        CONCAT(''Desc taxon '', i),
        i
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.items (item_id, tenant_id, name, title, description, sku)
    SELECT
        i,
        i,
        CONCAT(''ProductoGT_'', i),
        CONCAT(''TituloProd'', i),
        CONCAT(''Descripcion producto #'', i),
        CONCAT(''SKU-GT-'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.item_taxons (item_id, taxon_id)
    SELECT
        i,
        i
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.variations (variation_id, tenant_id, item_id, label, variation_sku, price)
    SELECT
        i,
        i,
        i,
        CONCAT(''VarLabel_'', i),
        CONCAT(''VAR-SKU-'', i),
        (10 + i)::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.digital_assets (digital_asset_id, tenant_id, item_id, variation_id, asset_type, asset_url, asset_description)
    SELECT
        i,
        i,
        i,
        i,
        CASE WHEN i % 3=0 THEN ''VIDEO''::catalog.asset_type_enum
             WHEN i%3=1 THEN ''IMAGE''::catalog.asset_type_enum
             ELSE ''DOCUMENT''::catalog.asset_type_enum
        END,
        CONCAT(''http://assets.gt/img_'', i, ''.jpg''),
        CONCAT(''AssetDesc #'', i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.technical_specifications (technical_specification_id, tenant_id, item_id, size, material, warranty)
    SELECT
        i,
        i,
        i,
        CONCAT(i, ''cm x '', i, ''cm''),
        CONCAT(''Material_'', i),
        CONCAT(''Garantia_'', i, '' meses'')
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO catalog.user_review_product (review_id, tenant_id, product_id, user_id, rating_count, comment)
    SELECT
        i,
        i,
        i,
        i,
        (i % 5),
        CONCAT(''Reseña del user #'', i, ''. Excelente producto'')
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO offers.promotions (promotion_id, tenant_id, name, description, discount_type, discount_value, start_date, end_date)
    SELECT
        i,
        i,
        CONCAT(''PromoGT_'', i),
        CONCAT(''Desc promo #'', i),
        CASE WHEN i % 3=0 THEN ''BUY_X_GET_Y''::offers.discount_type_enum
             WHEN i % 2=0 THEN ''PERCENTAGE''::offers.discount_type_enum
             ELSE ''FIXED_AMOUNT''::offers.discount_type_enum
        END,
        i::NUMERIC,
        CURRENT_DATE,
        CURRENT_DATE + i
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO offers.promotion_product (promotion_id, item_id)
    SELECT
        i,
        i
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO offers.promotion_taxon (promotion_id, taxon_id)
    SELECT
        i,
        i
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO offers.promotion_rules (rule_id, promotion_id, rule_data)
    SELECT
        i,
        i,
        jsonb_build_object(
            ''min_quantity'', (i % 3 + 1),
            ''max_uses'', (10 + i),
            ''region'', CONCAT(''GuatemalaZona'', i)
        )
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.cart (cart_id, tenant_id, user_id, expires_at)
    SELECT
        i,
        i,
        i,
        NOW() + (i||'' day'')::INTERVAL
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.cart_item (cart_item_id, cart_id, item_id, quantity)
    SELECT
        i,
        i,
        i,
        (i % 5 + 1)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.order_headers (order_id, tenant_id, user_id, shipping_address_id, billing_address_id, total_amount)
    SELECT
        i,
        i,
        i,
        i,
        i,
        (50 + i)::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.order_lines (order_line_id, order_id, item_id, quantity, unit_price, total_price)
    SELECT
        i,
        i,
        i,
        (i % 5 + 1),
        (10 + i)::NUMERIC,
        (50 + i)::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.returns (return_id, tenant_id, order_id, user_id, item_id, reason, refund_amount)
    SELECT
        i,
        i,
        i,
        i,
        i,
        CONCAT(''Razón de devolución #'', i),
        (10 + i)::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.payment_methods (payment_method_id, tenant_id, user_id, method_type, token, masked_number, brand)
    SELECT
        i,
        i,
        i,
        CASE WHEN i % 2=0 THEN ''CREDIT_CARD'' ELSE ''PAYPAL'' END,
        CONCAT(''token_'', i),
        CONCAT(''****'', (1000 + i)),
        CASE WHEN i % 3=0 THEN ''VISA'' WHEN i%3=1 THEN ''MASTERCARD'' ELSE ''AMEX'' END
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.payment (payment_id, tenant_id, user_id, order_id, payment_method_id, transaction_id, amount)
    SELECT
        i,
        i,
        i,
        i,
        i,
        CONCAT(''txn_'', i),
        (50 + i)::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.invoice_headers (invoice_id, tenant_id, order_id, invoice_number, total_amount)
    SELECT
        i,
        i,
        i,
        CONCAT(''INV-GT-'', i),
        (100 + i)::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO orders.invoice_lines (invoice_line_id, invoice_id, description, quantity, unit_price, total_price)
    SELECT
        i,
        i,
        CONCAT(''Detalle Factura '', i),
        (i % 5 + 1),
        (20 + i)::NUMERIC,
        (50 + i)::NUMERIC
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO inventory.inventory_location (location_id, tenant_id, name, address_id)
    SELECT
        i,
        i,
        CONCAT(''BodegaGT_'', i),
        i
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO inventory.stocks (stock_id, tenant_id, location_id, item_id, variation_id, quantity)
    SELECT
        i,
        i,
        i,
        i,
        i,
        (10 + i)
    FROM generate_series(1,50) AS i
    ';

    EXECUTE '
    INSERT INTO inventory.stock_movements (movement_id, tenant_id, stock_id, movement_type, quantity, reason)
    SELECT
        i,
        i,
        i,
        CASE WHEN i % 3=0 THEN ''INBOUND'' WHEN i%3=1 THEN ''OUTBOUND'' ELSE ''ADJUST'' END,
        (i % 20 + 1),
        CONCAT(''Movimiento #'', i)
    FROM generate_series(1,50) AS i
    ';

    RAISE NOTICE 'Datos de prueba insertados exitosamente.';

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'ERROR al insertar datos de prueba. Haciendo ROLLBACK.';
    RAISE NOTICE 'Código de error: %', SQLSTATE;
    RAISE NOTICE 'Mensaje de error: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;