-- =======================================================
-- FILE: ddl.sql
-- Script de creación de la base de datos, usuario, esquemas, tipos,
-- tablas y sus comentarios, usando transacciones y EXECUTE.
-- =======================================================

-- 1) Eliminar la base de datos y el usuario si ya existen
--DROP DATABASE IF EXISTS ecommerce;
--DROP USER IF EXISTS my_user;
--
-- 2) Crear el usuario y la base de datos con OWNER
--CREATE USER my_user WITH PASSWORD 'my_password';
--ALTER ROLE my_user WITH CREATEDB;
--
--CREATE DATABASE ecommerce
--    WITH OWNER = my_user
--    ENCODING = 'UTF8'
--    LC_COLLATE = 'en_US.UTF-8'
--    LC_CTYPE = 'en_US.UTF-8'
--    TEMPLATE = template0;

-- IMPORTANTE: En psql se haría:
--   \c ecommerce
-- O en tu cliente, conectarse ahora a la base 'ecommerce' como 'my_user'.
-- Por ejemplo en DBeaver, cambia de conexión a la BD ecommerce con el usuario 'my_user'.

-- 3) Definición de estructuras dentro de un bloque DO
--    (con EXECUTE para cada create, evitando errores de delimitadores)

DO $$
BEGIN
    RAISE NOTICE 'Iniciando la creación de esquemas, tipos y tablas...';

    -- -------------------------------------------------------------------------
    -- Eliminar objetos en orden inverso, por si se reejecuta
    -- -------------------------------------------------------------------------
    EXECUTE 'DROP SCHEMA IF EXISTS inventory  CASCADE';
    EXECUTE 'DROP SCHEMA IF EXISTS orders     CASCADE';
    EXECUTE 'DROP SCHEMA IF EXISTS offers     CASCADE';
    EXECUTE 'DROP SCHEMA IF EXISTS catalog    CASCADE';
    EXECUTE 'DROP SCHEMA IF EXISTS common     CASCADE';
    EXECUTE 'DROP SCHEMA IF EXISTS security   CASCADE';
    EXECUTE 'DROP SCHEMA IF EXISTS tenants    CASCADE';

    -- -------------------------------------------------------------------------
    -- Creación de esquemas
    -- -------------------------------------------------------------------------
    EXECUTE 'CREATE SCHEMA tenants';
    EXECUTE 'CREATE SCHEMA security';
    EXECUTE 'CREATE SCHEMA common';
    EXECUTE 'CREATE SCHEMA catalog';
    EXECUTE 'CREATE SCHEMA offers';
    EXECUTE 'CREATE SCHEMA orders';
    EXECUTE 'CREATE SCHEMA inventory';

    -- -------------------------------------------------------------------------
    -- Función global update_timestamp
    -- -------------------------------------------------------------------------
    EXECUTE '
        CREATE OR REPLACE FUNCTION update_timestamp()
        RETURNS TRIGGER AS $BODY$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $BODY$ LANGUAGE plpgsql;
    ';

    -- -------------------------------------------------------------------------
    -- 1) SCHEMA: tenants
    -- -------------------------------------------------------------------------
    EXECUTE '
        CREATE TYPE tenants.plan_type_enum AS ENUM (''FREE'',''STANDARD'',''PREMIUM'',''ENTERPRISE'');
    ';

    EXECUTE '
        CREATE TABLE tenants.tenants (
            tenant_id BIGSERIAL PRIMARY KEY,
            business_name VARCHAR(255) NOT NULL,
            owner_name    VARCHAR(255) NOT NULL,
            email         VARCHAR(255) NOT NULL UNIQUE,
            password      VARCHAR(255) NOT NULL,
            subscription_plan tenants.plan_type_enum NOT NULL DEFAULT ''FREE'',
            created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at    TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE tenants.tenants IS ''Listado de clientes (tenants) en el modelo SaaS.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.tenant_id IS ''Identificador único del tenant.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.business_name IS ''Nombre comercial de la empresa o cliente.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.owner_name IS ''Nombre de la persona propietaria.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.email IS ''Correo principal del tenant.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.password IS ''Hash de contraseña.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.subscription_plan IS ''Plan suscrito: FREE, STANDARD, PREMIUM, ENTERPRISE.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.created_at IS ''Fecha de creación del registro.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.updated_at IS ''Última fecha de modificación.''';

    EXECUTE '
        CREATE TRIGGER trg_tenants_update_timestamp
        BEFORE UPDATE ON tenants.tenants
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    -- -------------------------------------------------------------------------
    -- 2) SCHEMA: security
    -- -------------------------------------------------------------------------
    EXECUTE '
        CREATE TYPE security.role_enum AS ENUM (''ADMIN'',''EMPLOYEE'',''CUSTOMER'');
    ';

    EXECUTE '
        CREATE TABLE security.users (
            user_id   BIGSERIAL PRIMARY KEY,
            tenant_id BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            name      VARCHAR(255) NOT NULL,
            email     VARCHAR(255) NOT NULL UNIQUE,
            password  VARCHAR(255) NOT NULL,
            role      security.role_enum NOT NULL DEFAULT ''CUSTOMER'',
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE security.users IS ''Usuarios finales, multi-tenant.''';

    EXECUTE '
        CREATE TRIGGER trg_users_update_timestamp
        BEFORE UPDATE ON security.users
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE security.employees (
            employee_id BIGSERIAL PRIMARY KEY,
            tenant_id   BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            name        VARCHAR(255) NOT NULL,
            email       VARCHAR(255) NOT NULL UNIQUE,
            password    VARCHAR(255) NOT NULL,
            role        security.role_enum NOT NULL DEFAULT ''EMPLOYEE'',
            created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE security.employees IS ''Staff o empleados de cada tenant.''';

    EXECUTE '
        CREATE TRIGGER trg_employees_update_timestamp
        BEFORE UPDATE ON security.employees
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    -- -------------------------------------------------------------------------
    -- 3) SCHEMA: common
    -- -------------------------------------------------------------------------
    EXECUTE '
        CREATE TABLE common.country (
            country_id BIGSERIAL PRIMARY KEY,
            name       VARCHAR(100) NOT NULL,
            code       VARCHAR(10)  NOT NULL
        );
    ';

    EXECUTE 'COMMENT ON TABLE common.country IS ''Listado de países.''';

    EXECUTE '
        CREATE TABLE common.states (
            state_id   BIGSERIAL PRIMARY KEY,
            country_id BIGINT NOT NULL REFERENCES common.country(country_id) ON DELETE CASCADE,
            name       VARCHAR(100) NOT NULL,
            code       VARCHAR(10)
        );
    ';

    EXECUTE 'COMMENT ON TABLE common.states IS ''Departamentos/estados de un país.''';

    EXECUTE '
        CREATE TABLE common.addresses (
            address_id    BIGSERIAL PRIMARY KEY,
            tenant_id     BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            user_id       BIGINT,
            address_line1 VARCHAR(255) NOT NULL,
            address_line2 VARCHAR(255),
            city          VARCHAR(100) NOT NULL,
            postal_code   VARCHAR(20),
            state_id      BIGINT REFERENCES common.states(state_id) ON DELETE SET NULL,
            country_id    BIGINT REFERENCES common.country(country_id) ON DELETE SET NULL,
            created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at    TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE common.addresses IS ''Direcciones postales, multi-tenant.''';

    EXECUTE '
        CREATE TRIGGER trg_addresses_update_timestamp
        BEFORE UPDATE ON common.addresses
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE common.phone_numbers (
            phone_id   BIGSERIAL PRIMARY KEY,
            tenant_id  BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            user_id    BIGINT,
            number     VARCHAR(50) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE common.phone_numbers IS ''Teléfonos asociados a usuarios o cuentas.''';

    EXECUTE '
        CREATE TRIGGER trg_phone_numbers_update_timestamp
        BEFORE UPDATE ON common.phone_numbers
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    -- -------------------------------------------------------------------------
    -- 4) SCHEMA: catalog
    -- -------------------------------------------------------------------------
    EXECUTE '
        CREATE TABLE catalog.taxonomies (
            taxonomy_id   BIGSERIAL PRIMARY KEY,
            tenant_id     BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            name          VARCHAR(255) NOT NULL,
            description   TEXT,
            created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at    TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE catalog.taxonomies IS ''Agrupaciones de clasificación, e.g. categorías principales.''';

    EXECUTE '
        CREATE TRIGGER trg_taxonomies_update_timestamp
        BEFORE UPDATE ON catalog.taxonomies
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE catalog.taxons (
            taxon_id    BIGSERIAL PRIMARY KEY,
            tenant_id   BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            taxonomy_id BIGINT NOT NULL REFERENCES catalog.taxonomies(taxonomy_id) ON DELETE CASCADE,
            name        VARCHAR(255) NOT NULL,
            description TEXT,
            parent_id   BIGINT,
            position    INT DEFAULT 0,
            created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
            CONSTRAINT fk_taxons_parent
                FOREIGN KEY (parent_id)
                REFERENCES catalog.taxons(taxon_id)
                ON DELETE CASCADE
        );
    ';

    EXECUTE 'COMMENT ON TABLE catalog.taxons IS ''Nodos específicos de una taxonomía (subcategorías, etc.).''';

    EXECUTE '
        CREATE TRIGGER trg_taxons_update_timestamp
        BEFORE UPDATE ON catalog.taxons
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE catalog.items (
            item_id     BIGSERIAL PRIMARY KEY,
            tenant_id   BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            name        VARCHAR(255) NOT NULL,
            title       VARCHAR(255),
            description TEXT,
            sku         VARCHAR(100),
            upc         VARCHAR(100),
            ean         VARCHAR(100),
            created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE catalog.items IS ''Tabla principal de productos.''';

    EXECUTE '
        CREATE TRIGGER trg_items_update_timestamp
        BEFORE UPDATE ON catalog.items
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE catalog.item_taxons (
            item_id  BIGINT NOT NULL REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            taxon_id BIGINT NOT NULL REFERENCES catalog.taxons(taxon_id) ON DELETE CASCADE,
            PRIMARY KEY (item_id, taxon_id)
        );
    ';

    EXECUTE 'COMMENT ON TABLE catalog.item_taxons IS ''Relación N:N entre items y taxons.''' ;

    EXECUTE '
        CREATE TYPE catalog.asset_type_enum AS ENUM (''IMAGE'',''VIDEO'',''DOCUMENT'');
    ';

    EXECUTE '
        CREATE TABLE catalog.variations (
            variation_id         BIGSERIAL PRIMARY KEY,
            tenant_id            BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            item_id              BIGINT NOT NULL REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            label                VARCHAR(255),
            variation_sku        VARCHAR(100),
            variation_upc        VARCHAR(100),
            variation_ean        VARCHAR(100),
            quantity_in_stock    INT NOT NULL DEFAULT 0 CHECK (quantity_in_stock >= 0),
            price                NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
            variation_attributes JSONB,
            created_at           TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at           TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE catalog.variations IS ''Variantes específicas de un producto (ej. talla, color).''';

    EXECUTE '
        CREATE TRIGGER trg_variations_update_timestamp
        BEFORE UPDATE ON catalog.variations
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE catalog.digital_assets (
            digital_asset_id BIGSERIAL PRIMARY KEY,
            tenant_id        BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            item_id          BIGINT REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            variation_id     BIGINT REFERENCES catalog.variations(variation_id) ON DELETE CASCADE,
            asset_type       catalog.asset_type_enum NOT NULL,
            asset_url        TEXT NOT NULL,
            asset_description VARCHAR(255),
            created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at       TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE catalog.digital_assets IS ''Recursos digitales (imágenes, videos, docs) asociados a items/variaciones.''';

    EXECUTE '
        CREATE TRIGGER trg_digital_assets_update_timestamp
        BEFORE UPDATE ON catalog.digital_assets
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE catalog.technical_specifications (
            technical_specification_id BIGSERIAL PRIMARY KEY,
            tenant_id                  BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            item_id                    BIGINT NOT NULL REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            size                       VARCHAR(50),
            material                   VARCHAR(100),
            warranty                   VARCHAR(255),
            ingredients                TEXT,
            created_at                 TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at                 TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE catalog.technical_specifications IS ''Información técnica detallada por producto.''';

    EXECUTE '
        CREATE TRIGGER trg_tech_specs_update_timestamp
        BEFORE UPDATE ON catalog.technical_specifications
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE catalog.user_review_product (
            review_id    BIGSERIAL PRIMARY KEY,
            tenant_id    BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            product_id   BIGINT NOT NULL REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            user_id      BIGINT NOT NULL REFERENCES security.users(user_id) ON DELETE CASCADE,
            rating_count INT NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
            comment      TEXT,
            created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE catalog.user_review_product IS ''Reseñas de usuarios sobre productos.''';

    EXECUTE '
        CREATE TRIGGER trg_user_review_update_timestamp
        BEFORE UPDATE ON catalog.user_review_product
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    -- -------------------------------------------------------------------------
    -- 5) SCHEMA: offers
    -- -------------------------------------------------------------------------
    EXECUTE '
        CREATE TYPE offers.discount_type_enum AS ENUM (''PERCENTAGE'',''FIXED_AMOUNT'',''BUY_X_GET_Y'');
    ';

    EXECUTE '
        CREATE TABLE offers.promotions (
            promotion_id   BIGSERIAL PRIMARY KEY,
            tenant_id      BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            name           VARCHAR(255) NOT NULL,
            description    TEXT,
            discount_type  offers.discount_type_enum NOT NULL,
            discount_value NUMERIC(12,2) NOT NULL DEFAULT 0,
            start_date     DATE NOT NULL,
            end_date       DATE NOT NULL,
            created_at     TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at     TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE offers.promotions IS ''Tabla principal para promociones y descuentos.''';

    EXECUTE '
        CREATE TRIGGER trg_promotions_update_timestamp
        BEFORE UPDATE ON offers.promotions
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE offers.promotion_product (
            promotion_id BIGINT NOT NULL REFERENCES offers.promotions(promotion_id) ON DELETE CASCADE,
            item_id      BIGINT NOT NULL REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            PRIMARY KEY (promotion_id, item_id)
        );
    ';

    EXECUTE 'COMMENT ON TABLE offers.promotion_product IS ''Asocia promociones a productos específicos.''';

    EXECUTE '
        CREATE TABLE offers.promotion_taxon (
            promotion_id BIGINT NOT NULL REFERENCES offers.promotions(promotion_id) ON DELETE CASCADE,
            taxon_id     BIGINT NOT NULL REFERENCES catalog.taxons(taxon_id) ON DELETE CASCADE,
            PRIMARY KEY (promotion_id, taxon_id)
        );
    ';

    EXECUTE 'COMMENT ON TABLE offers.promotion_taxon IS ''Asocia promociones a taxons (categorías o subcategorías).''';

    EXECUTE '
        CREATE TABLE offers.promotion_rules (
            rule_id      BIGSERIAL PRIMARY KEY,
            promotion_id BIGINT NOT NULL REFERENCES offers.promotions(promotion_id) ON DELETE CASCADE,
            rule_data    JSONB NOT NULL,
            created_at   TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE offers.promotion_rules IS ''Reglas extras (JSON) para promociones.''';

    -- -------------------------------------------------------------------------
    -- 6) SCHEMA: orders
    -- -------------------------------------------------------------------------
    EXECUTE '
        CREATE TYPE orders.order_status_enum AS ENUM (''CREATED'',''PAID'',''SHIPPED'',''DELIVERED'',''CANCELED'',''REFUNDED'');
    ';

    EXECUTE '
        CREATE TYPE orders.payment_status_enum AS ENUM (''PENDING'',''COMPLETED'',''FAILED'',''REFUNDED'');
    ';

    EXECUTE '
        CREATE TYPE orders.invoice_status_enum AS ENUM (''DRAFT'',''ISSUED'',''PAID'',''CANCELED'');
    ';

    EXECUTE '
        CREATE TYPE orders.return_status_enum AS ENUM (''REQUESTED'',''APPROVED'',''DENIED'',''REFUNDED'');
    ';

    EXECUTE '
        CREATE TABLE orders.cart (
            cart_id    BIGSERIAL PRIMARY KEY,
            tenant_id  BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            user_id    BIGINT NOT NULL REFERENCES security.users(user_id) ON DELETE CASCADE,
            expires_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.cart IS ''Carrito de compras de un usuario.''';

    EXECUTE '
        CREATE TRIGGER trg_cart_update_timestamp
        BEFORE UPDATE ON orders.cart
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE orders.cart_item (
            cart_item_id BIGSERIAL PRIMARY KEY,
            cart_id      BIGINT NOT NULL REFERENCES orders.cart(cart_id) ON DELETE CASCADE,
            item_id      BIGINT NOT NULL REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            quantity     INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
            created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.cart_item IS ''Productos agregados al carrito.''' ;

    EXECUTE '
        CREATE TRIGGER trg_cart_item_update_timestamp
        BEFORE UPDATE ON orders.cart_item
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE orders.order_headers (
            order_id           BIGSERIAL PRIMARY KEY,
            tenant_id          BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            user_id            BIGINT NOT NULL REFERENCES security.users(user_id) ON DELETE CASCADE,
            shipping_address_id BIGINT REFERENCES common.addresses(address_id) ON DELETE SET NULL,
            billing_address_id  BIGINT REFERENCES common.addresses(address_id) ON DELETE SET NULL,
            status             orders.order_status_enum NOT NULL DEFAULT ''CREATED'',
            total_amount       NUMERIC(12,2) NOT NULL DEFAULT 0,
            created_at         TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at         TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.order_headers IS ''Encabezado de un pedido (orden).''';

    EXECUTE '
        CREATE TRIGGER trg_order_headers_update_timestamp
        BEFORE UPDATE ON orders.order_headers
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE orders.order_lines (
            order_line_id BIGSERIAL PRIMARY KEY,
            order_id      BIGINT NOT NULL REFERENCES orders.order_headers(order_id) ON DELETE CASCADE,
            item_id       BIGINT NOT NULL REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            quantity      INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
            unit_price    NUMERIC(12,2) NOT NULL DEFAULT 0,
            total_price   NUMERIC(12,2) NOT NULL DEFAULT 0,
            created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at    TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.order_lines IS ''Detalle de productos en la orden.''';

    EXECUTE '
        CREATE TRIGGER trg_order_lines_update_timestamp
        BEFORE UPDATE ON orders.order_lines
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE orders.returns (
            return_id    BIGSERIAL PRIMARY KEY,
            tenant_id    BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            order_id     BIGINT NOT NULL REFERENCES orders.order_headers(order_id) ON DELETE CASCADE,
            user_id      BIGINT NOT NULL REFERENCES security.users(user_id) ON DELETE CASCADE,
            item_id      BIGINT NOT NULL REFERENCES catalog.items(item_id) ON DELETE CASCADE,
            reason       TEXT,
            refund_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
            return_date  TIMESTAMP NOT NULL DEFAULT NOW(),
            status       orders.return_status_enum NOT NULL DEFAULT ''REQUESTED'',
            created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.returns IS ''Registros de devoluciones de productos.''';

    EXECUTE '
        CREATE TRIGGER trg_returns_update_timestamp
        BEFORE UPDATE ON orders.returns
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE orders.payment_methods (
            payment_method_id BIGSERIAL PRIMARY KEY,
            tenant_id         BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            user_id           BIGINT NOT NULL REFERENCES security.users(user_id) ON DELETE CASCADE,
            method_type       VARCHAR(50) NOT NULL,
            token             VARCHAR(255),
            masked_number     VARCHAR(20),
            brand             VARCHAR(50),
            created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at        TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.payment_methods IS ''Métodos de pago (tarjetas tokenizadas, etc.).''';

    EXECUTE '
        CREATE TRIGGER trg_payment_methods_update_timestamp
        BEFORE UPDATE ON orders.payment_methods
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE orders.payment (
            payment_id       BIGSERIAL PRIMARY KEY,
            tenant_id        BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            user_id          BIGINT NOT NULL REFERENCES security.users(user_id) ON DELETE CASCADE,
            order_id         BIGINT REFERENCES orders.order_headers(order_id) ON DELETE SET NULL,
            payment_method_id BIGINT REFERENCES orders.payment_methods(payment_method_id) ON DELETE SET NULL,
            transaction_id   VARCHAR(255),
            amount           NUMERIC(12,2) NOT NULL DEFAULT 0,
            status           orders.payment_status_enum NOT NULL DEFAULT ''PENDING'',
            created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at       TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.payment IS ''Registro de pagos realizados para una orden.''';

    EXECUTE '
        CREATE TRIGGER trg_payment_update_timestamp
        BEFORE UPDATE ON orders.payment
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE orders.invoice_headers (
            invoice_id    BIGSERIAL PRIMARY KEY,
            tenant_id     BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            order_id      BIGINT NOT NULL REFERENCES orders.order_headers(order_id) ON DELETE CASCADE,
            invoice_number VARCHAR(50) NOT NULL,
            status        orders.invoice_status_enum NOT NULL DEFAULT ''DRAFT'',
            total_amount  NUMERIC(12,2) NOT NULL DEFAULT 0,
            issued_at     TIMESTAMP,
            paid_at       TIMESTAMP,
            created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at    TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.invoice_headers IS ''Encabezado de factura asociada a un pedido.''';

    EXECUTE '
        CREATE TRIGGER trg_invoice_headers_update_timestamp
        BEFORE UPDATE ON orders.invoice_headers
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE orders.invoice_lines (
            invoice_line_id BIGSERIAL PRIMARY KEY,
            invoice_id      BIGINT NOT NULL REFERENCES orders.invoice_headers(invoice_id) ON DELETE CASCADE,
            description     VARCHAR(255),
            quantity        INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
            unit_price      NUMERIC(12,2) NOT NULL DEFAULT 0,
            total_price     NUMERIC(12,2) NOT NULL DEFAULT 0,
            created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE orders.invoice_lines IS ''Detalle de conceptos facturados.''';

    EXECUTE '
        CREATE TRIGGER trg_invoice_lines_update_timestamp
        BEFORE UPDATE ON orders.invoice_lines
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    -- -------------------------------------------------------------------------
    -- 7) SCHEMA: inventory
    -- -------------------------------------------------------------------------
    EXECUTE '
        CREATE TABLE inventory.inventory_location (
            location_id BIGSERIAL PRIMARY KEY,
            tenant_id   BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            name        VARCHAR(255) NOT NULL,
            address_id  BIGINT,
            created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
            CONSTRAINT fk_location_address
                FOREIGN KEY (address_id)
                REFERENCES common.addresses(address_id)
                ON DELETE SET NULL
        );
    ';

    EXECUTE 'COMMENT ON TABLE inventory.inventory_location IS ''Diferentes bodegas o almacenes (ubicaciones de stock).''';

    EXECUTE '
        CREATE TRIGGER trg_inventory_location_update_timestamp
        BEFORE UPDATE ON inventory.inventory_location
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE inventory.stocks (
            stock_id     BIGSERIAL PRIMARY KEY,
            tenant_id    BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            location_id  BIGINT NOT NULL REFERENCES inventory.inventory_location(location_id) ON DELETE CASCADE,
            item_id      BIGINT REFERENCES catalog.items(item_id) ON DELETE SET NULL,
            variation_id BIGINT REFERENCES catalog.variations(variation_id) ON DELETE SET NULL,
            quantity     INT NOT NULL DEFAULT 0,
            created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE inventory.stocks IS ''Cantidad de stock de un producto/variación en una ubicación dada.''';

    EXECUTE '
        CREATE TRIGGER trg_stocks_update_timestamp
        BEFORE UPDATE ON inventory.stocks
        FOR EACH ROW
        EXECUTE FUNCTION update_timestamp();
    ';

    EXECUTE '
        CREATE TABLE inventory.stock_movements (
            movement_id  BIGSERIAL PRIMARY KEY,
            tenant_id    BIGINT NOT NULL REFERENCES tenants.tenants(tenant_id) ON DELETE CASCADE,
            stock_id     BIGINT NOT NULL REFERENCES inventory.stocks(stock_id) ON DELETE CASCADE,
            movement_type VARCHAR(50) NOT NULL,
            quantity     INT NOT NULL,
            reason       TEXT,
            created_at   TIMESTAMP NOT NULL DEFAULT NOW()
        );
    ';

    EXECUTE 'COMMENT ON TABLE inventory.stock_movements IS ''Historial de entradas/salidas/ajustes de stock.''';

    RAISE NOTICE 'Creación de esquemas, tipos y tablas finalizada exitosamente.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR al crear la estructura. Código: % - Mensaje: %', SQLSTATE, SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- Otorgar permisos al usuario en todos los schemas (opcional):
-- GRANT ALL PRIVILEGES ON SCHEMA tenants   TO my_user;
-- GRANT ALL PRIVILEGES ON SCHEMA security  TO my_user;
-- GRANT ALL PRIVILEGES ON SCHEMA common    TO my_user;
-- GRANT ALL PRIVILEGES ON SCHEMA catalog   TO my_user;
-- GRANT ALL PRIVILEGES ON SCHEMA offers    TO my_user;
-- GRANT ALL PRIVILEGES ON SCHEMA orders    TO my_user;
-- GRANT ALL PRIVILEGES ON SCHEMA inventory TO my_user;

-- Otorgar permisos a tablas y secuencias existentes:
-- (requiere la extensión: CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"; / \"pgcrypto\"; etc.)
-- GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA tenants,security,common,catalog,offers,orders,inventory TO my_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA tenants,security,common,catalog,offers,orders,inventory TO my_user;