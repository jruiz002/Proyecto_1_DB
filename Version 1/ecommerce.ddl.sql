-- =======================================================
-- FILE: ddl.sql
-- Script de creación de la base de datos, esquemas, tipos,
-- tablas y sus comentarios, usando transacciones y EXECUTE.
-- =======================================================

/* 1) Eliminar la base de datos y usuario si ya existen */
DROP DATABASE IF EXISTS ecommerce;
DROP USER IF EXISTS my_user;

/* 2) Crear el usuario y la base de datos con OWNER */
CREATE USER my_user WITH PASSWORD 'my_password';
ALTER ROLE my_user WITH CREATEDB;

CREATE DATABASE ecommerce
    WITH OWNER = my_user
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

/* 3) A partir de aquí, se asume que se conecta a "ecommerce".
   En psql sería: \c ecommerce
   O en client: psql -h localhost -U my_user -d ecommerce -f ddl.sql
*/

/* 4) Definición de estructuras dentro de un bloque DO con transacción */

DO $$
BEGIN
    RAISE NOTICE 'Iniciando la creación de esquemas, tipos y tablas...';

    BEGIN;  -- Iniciamos transacción

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
    EXECUTE $q$
        CREATE OR REPLACE FUNCTION update_timestamp()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    $q$;

    -- -------------------------------------------------------------------------
    -- 1) SCHEMA: tenants
    -- -------------------------------------------------------------------------

    -- Enum plan_type_enum
    EXECUTE $q$
        CREATE TYPE tenants.plan_type_enum AS ENUM ('FREE','STANDARD','PREMIUM','ENTERPRISE')
    $q$;

    -- Tabla tenants.tenants
    EXECUTE $q$
    CREATE TABLE tenants.tenants (
        tenant_id BIGSERIAL PRIMARY KEY,
        business_name VARCHAR(255) NOT NULL,
        owner_name    VARCHAR(255) NOT NULL,
        email         VARCHAR(255) NOT NULL UNIQUE,
        password      VARCHAR(255) NOT NULL,
        subscription_plan tenants.plan_type_enum NOT NULL DEFAULT 'FREE',
        created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMP NOT NULL DEFAULT NOW()
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE tenants.tenants IS ''Listado de clientes (tenants) en el modelo SaaS.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.tenant_id IS ''Identificador único del tenant.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.business_name IS ''Nombre comercial de la empresa o cliente.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.owner_name IS ''Nombre de la persona propietaria.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.email IS ''Correo principal del tenant.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.password IS ''Hash de contraseña.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.subscription_plan IS ''Plan suscrito: FREE, STANDARD, PREMIUM, ENTERPRISE.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.created_at IS ''Fecha de creación del registro.''';
    EXECUTE 'COMMENT ON COLUMN tenants.tenants.updated_at IS ''Última fecha de modificación.''';

    EXECUTE $q$
    CREATE TRIGGER trg_tenants_update_timestamp
    BEFORE UPDATE ON tenants.tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;


    -- -------------------------------------------------------------------------
    -- 2) SCHEMA: security
    -- -------------------------------------------------------------------------
    EXECUTE $q$
        CREATE TYPE security.role_enum AS ENUM ('ADMIN','EMPLOYEE','CUSTOMER')
    $q$;

    EXECUTE $q$
    CREATE TABLE security.users (
        user_id   BIGSERIAL PRIMARY KEY,
        tenant_id BIGINT NOT NULL,
        name      VARCHAR(255) NOT NULL,
        email     VARCHAR(255) NOT NULL UNIQUE,
        password  VARCHAR(255) NOT NULL,
        role      security.role_enum NOT NULL DEFAULT 'CUSTOMER',
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_users_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE security.users IS ''Usuarios finales, multi-tenant.''';
    EXECUTE 'COMMENT ON COLUMN security.users.user_id IS ''Identificador del usuario.''';
    EXECUTE 'COMMENT ON COLUMN security.users.tenant_id IS ''FK al tenant (multi-tenant).''';
    EXECUTE 'COMMENT ON COLUMN security.users.name IS ''Nombre del usuario.''';
    EXECUTE 'COMMENT ON COLUMN security.users.email IS ''Correo del usuario (login).''';
    EXECUTE 'COMMENT ON COLUMN security.users.password IS ''Hash de contraseña del usuario.''';
    EXECUTE 'COMMENT ON COLUMN security.users.role IS ''Rol principal: CUSTOMER, ADMIN, EMPLOYEE.''';
    EXECUTE 'COMMENT ON COLUMN security.users.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN security.users.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_users_update_timestamp
    BEFORE UPDATE ON security.users
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE security.employees (
        employee_id BIGSERIAL PRIMARY KEY,
        tenant_id   BIGINT NOT NULL,
        name        VARCHAR(255) NOT NULL,
        email       VARCHAR(255) NOT NULL UNIQUE,
        password    VARCHAR(255) NOT NULL,
        role        security.role_enum NOT NULL DEFAULT 'EMPLOYEE',
        created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_employees_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE security.employees IS ''Staff o empleados de cada tenant.''';
    EXECUTE 'COMMENT ON COLUMN security.employees.employee_id IS ''Identificador del empleado.''';
    EXECUTE 'COMMENT ON COLUMN security.employees.tenant_id IS ''FK al tenant (multi-tenant).''';
    EXECUTE 'COMMENT ON COLUMN security.employees.name IS ''Nombre del empleado.''';
    EXECUTE 'COMMENT ON COLUMN security.employees.email IS ''Correo del empleado (login).''';
    EXECUTE 'COMMENT ON COLUMN security.employees.password IS ''Hash de contraseña del empleado.''';
    EXECUTE 'COMMENT ON COLUMN security.employees.role IS ''Rol del empleado (ADMIN o EMPLOYEE).''';
    EXECUTE 'COMMENT ON COLUMN security.employees.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN security.employees.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_employees_update_timestamp
    BEFORE UPDATE ON security.employees
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    -- -------------------------------------------------------------------------
    -- 3) SCHEMA: common
    -- -------------------------------------------------------------------------
    EXECUTE $q$
    CREATE TABLE common.country (
        country_id BIGSERIAL PRIMARY KEY,
        name       VARCHAR(100) NOT NULL,
        code       VARCHAR(10)  NOT NULL
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE common.country IS ''Listado de países.''';
    EXECUTE 'COMMENT ON COLUMN common.country.country_id IS ''Identificador del país.''';
    EXECUTE 'COMMENT ON COLUMN common.country.name IS ''Nombre del país.''';
    EXECUTE 'COMMENT ON COLUMN common.country.code IS ''Código ISO del país.''';

    EXECUTE $q$
    CREATE TABLE common.states (
        state_id   BIGSERIAL PRIMARY KEY,
        country_id BIGINT NOT NULL,
        name       VARCHAR(100) NOT NULL,
        code       VARCHAR(10),
        CONSTRAINT fk_states_country
          FOREIGN KEY (country_id)
          REFERENCES common.country (country_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE common.states IS ''Departamentos/estados de un país.''';
    EXECUTE 'COMMENT ON COLUMN common.states.state_id IS ''Identificador del departamento/estado.''';
    EXECUTE 'COMMENT ON COLUMN common.states.country_id IS ''FK a common.country.''';
    EXECUTE 'COMMENT ON COLUMN common.states.name IS ''Nombre del departamento/estado.''';
    EXECUTE 'COMMENT ON COLUMN common.states.code IS ''Código abreviado del estado.''';

    EXECUTE $q$
    CREATE TABLE common.addresses (
        address_id    BIGSERIAL PRIMARY KEY,
        tenant_id     BIGINT NOT NULL,
        user_id       BIGINT,
        address_line1 VARCHAR(255) NOT NULL,
        address_line2 VARCHAR(255),
        city          VARCHAR(100) NOT NULL,
        postal_code   VARCHAR(20),
        state_id      BIGINT,
        country_id    BIGINT,
        created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_address_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE common.addresses IS ''Direcciones postales, multi-tenant.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.address_id IS ''Identificador de la dirección.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.user_id IS ''Usuario dueño de la dirección (opcional).''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.address_line1 IS ''Calle principal, número, etc.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.address_line2 IS ''Detalles adicionales de la dirección.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.city IS ''Ciudad.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.postal_code IS ''Código postal.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.state_id IS ''FK a common.states.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.country_id IS ''FK a common.country.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN common.addresses.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_addresses_update_timestamp
    BEFORE UPDATE ON common.addresses
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE common.phone_numbers (
        phone_id   BIGSERIAL PRIMARY KEY,
        tenant_id  BIGINT NOT NULL,
        user_id    BIGINT,
        number     VARCHAR(50) NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_phone_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE common.phone_numbers IS ''Teléfonos asociados a usuarios o cuentas.''';
    EXECUTE 'COMMENT ON COLUMN common.phone_numbers.phone_id IS ''Identificador del teléfono.''';
    EXECUTE 'COMMENT ON COLUMN common.phone_numbers.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN common.phone_numbers.user_id IS ''FK al usuario (opcional).''';
    EXECUTE 'COMMENT ON COLUMN common.phone_numbers.number IS ''Número telefónico.''';
    EXECUTE 'COMMENT ON COLUMN common.phone_numbers.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN common.phone_numbers.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_phone_numbers_update_timestamp
    BEFORE UPDATE ON common.phone_numbers
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;


    -- -------------------------------------------------------------------------
    -- 4) SCHEMA: catalog
    -- -------------------------------------------------------------------------
    EXECUTE $q$
    CREATE TABLE catalog.taxonomies (
        taxonomy_id   BIGSERIAL PRIMARY KEY,
        tenant_id     BIGINT NOT NULL,
        name          VARCHAR(255) NOT NULL,
        description   TEXT,
        created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_taxonomies_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE catalog.taxonomies IS ''Agrupaciones de clasificación, e.g. categorías principales.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxonomies.taxonomy_id IS ''Identificador de la taxonomía.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxonomies.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxonomies.name IS ''Nombre de la taxonomía (p.ej. Categorías).''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxonomies.description IS ''Descripción de la taxonomía.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxonomies.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxonomies.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_taxonomies_update_timestamp
    BEFORE UPDATE ON catalog.taxonomies
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE catalog.taxons (
        taxon_id    BIGSERIAL PRIMARY KEY,
        tenant_id   BIGINT NOT NULL,
        taxonomy_id BIGINT NOT NULL,
        name        VARCHAR(255) NOT NULL,
        description TEXT,
        parent_id   BIGINT,
        position    INT DEFAULT 0,
        created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_taxons_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_taxons_taxonomy
          FOREIGN KEY (taxonomy_id)
          REFERENCES catalog.taxonomies (taxonomy_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_taxons_parent
          FOREIGN KEY (parent_id)
          REFERENCES catalog.taxons (taxon_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE catalog.taxons IS ''Nodos específicos de una taxonomía (subcategorías, etc.).''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.taxon_id IS ''Identificador del taxon.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.taxonomy_id IS ''FK a catalog.taxonomies.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.name IS ''Nombre del taxon.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.description IS ''Descripción del taxon.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.parent_id IS ''Referencia para taxon padre (jerarquía).''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.position IS ''Orden de visualización.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.taxons.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_taxons_update_timestamp
    BEFORE UPDATE ON catalog.taxons
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE catalog.items (
        item_id     BIGSERIAL PRIMARY KEY,
        tenant_id   BIGINT NOT NULL,
        name        VARCHAR(255) NOT NULL,
        title       VARCHAR(255),
        description TEXT,
        sku         VARCHAR(100),
        upc         VARCHAR(100),
        ean         VARCHAR(100),
        created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_items_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE catalog.items IS ''Tabla principal de productos.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.item_id IS ''Identificador del producto.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.name IS ''Nombre del producto.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.title IS ''Título descriptivo del producto.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.description IS ''Descripción larga del producto.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.sku IS ''Stock Keeping Unit (código interno).''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.upc IS ''Universal Product Code.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.ean IS ''European Article Number.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.items.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_items_update_timestamp
    BEFORE UPDATE ON catalog.items
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE catalog.item_taxons (
        item_id  BIGINT NOT NULL,
        taxon_id BIGINT NOT NULL,
        PRIMARY KEY (item_id, taxon_id),
        CONSTRAINT fk_item_taxons_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_item_taxons_taxon
          FOREIGN KEY (taxon_id)
          REFERENCES catalog.taxons (taxon_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE catalog.item_taxons IS ''Relación N:N entre items y taxons.''';

    EXECUTE $q$
    CREATE TYPE catalog.asset_type_enum AS ENUM ('IMAGE','VIDEO','DOCUMENT')
    $q$;

    EXECUTE $q$
    CREATE TABLE catalog.variations (
        variation_id         BIGSERIAL PRIMARY KEY,
        tenant_id            BIGINT NOT NULL,
        item_id              BIGINT NOT NULL,
        label                VARCHAR(255),
        variation_sku        VARCHAR(100),
        variation_upc        VARCHAR(100),
        variation_ean        VARCHAR(100),
        quantity_in_stock    INT NOT NULL DEFAULT 0 CHECK (quantity_in_stock >= 0),
        price                NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
        variation_attributes JSONB,
        created_at           TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at           TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_variations_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_variations_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE catalog.variations IS ''Variantes específicas de un producto (ej. talla, color).''';

    EXECUTE 'COMMENT ON COLUMN catalog.variations.variation_id IS ''Identificador de la variación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.item_id IS ''FK a catalog.items.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.label IS ''Etiqueta descriptiva (p.ej. Color: Rojo).''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.variation_sku IS ''SKU específico de la variación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.variation_upc IS ''UPC específico.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.variation_ean IS ''EAN específico.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.quantity_in_stock IS ''Cantidad en inventario para esta variación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.price IS ''Precio de la variación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.variation_attributes IS ''JSON con atributos dinámicos.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.variations.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_variations_update_timestamp
    BEFORE UPDATE ON catalog.variations
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE catalog.digital_assets (
        digital_asset_id BIGSERIAL PRIMARY KEY,
        tenant_id        BIGINT NOT NULL,
        item_id          BIGINT,
        variation_id     BIGINT,
        asset_type       catalog.asset_type_enum NOT NULL,
        asset_url        TEXT NOT NULL,
        asset_description VARCHAR(255),
        created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at       TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_digital_assets_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_digital_assets_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_digital_assets_variation
          FOREIGN KEY (variation_id)
          REFERENCES catalog.variations (variation_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE catalog.digital_assets IS ''Recursos digitales (imágenes, videos, docs) asociados a items/variaciones.''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.digital_asset_id IS ''Identificador del recurso digital.''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.item_id IS ''FK a catalog.items (opcional).''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.variation_id IS ''FK a catalog.variations (opcional).''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.asset_type IS ''Tipo de recurso: IMAGE, VIDEO, DOCUMENT.''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.asset_url IS ''URL del archivo digital.''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.asset_description IS ''Descripción o título del recurso.''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.digital_assets.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_digital_assets_update_timestamp
    BEFORE UPDATE ON catalog.digital_assets
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE catalog.technical_specifications (
        technical_specification_id BIGSERIAL PRIMARY KEY,
        tenant_id                  BIGINT NOT NULL,
        item_id                    BIGINT NOT NULL,
        size                       VARCHAR(50),
        material                   VARCHAR(100),
        warranty                   VARCHAR(255),
        ingredients                TEXT,
        created_at                 TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at                 TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_tech_specs_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_tech_specs_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE catalog.technical_specifications IS ''Información técnica detallada por producto.''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.technical_specification_id IS ''Identificador de la especificación técnica.''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.item_id IS ''FK a catalog.items.''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.size IS ''Tamaño del producto.''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.material IS ''Material principal.''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.warranty IS ''Información de garantía.''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.ingredients IS ''Ingredientes (para productos alimenticios).''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.technical_specifications.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_tech_specs_update_timestamp
    BEFORE UPDATE ON catalog.technical_specifications
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE catalog.user_review_product (
        review_id    BIGSERIAL PRIMARY KEY,
        tenant_id    BIGINT NOT NULL,
        product_id   BIGINT NOT NULL,
        user_id      BIGINT NOT NULL,
        rating_count INT NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
        comment      TEXT,
        created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_review_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_review_product
          FOREIGN KEY (product_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_review_user
          FOREIGN KEY (user_id)
          REFERENCES security.users (user_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE catalog.user_review_product IS ''Reseñas de usuarios sobre productos.''';
    EXECUTE 'COMMENT ON COLUMN catalog.user_review_product.review_id IS ''Identificador de la reseña.''';
    EXECUTE 'COMMENT ON COLUMN catalog.user_review_product.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN catalog.user_review_product.product_id IS ''FK a catalog.items.''';
    EXECUTE 'COMMENT ON COLUMN catalog.user_review_product.user_id IS ''FK a security.users (usuario que reseña).''';
    EXECUTE 'COMMENT ON COLUMN catalog.user_review_product.rating_count IS ''Puntuación de la reseña (0..5).''';
    EXECUTE 'COMMENT ON COLUMN catalog.user_review_product.comment IS ''Comentario del usuario reseñador.''';
    EXECUTE 'COMMENT ON COLUMN catalog.user_review_product.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN catalog.user_review_product.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_user_review_update_timestamp
    BEFORE UPDATE ON catalog.user_review_product
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;


    -- -------------------------------------------------------------------------
    -- 5) SCHEMA: offers
    -- -------------------------------------------------------------------------
    EXECUTE $q$
    CREATE TYPE offers.discount_type_enum AS ENUM ('PERCENTAGE','FIXED_AMOUNT','BUY_X_GET_Y')
    $q$;

    EXECUTE $q$
    CREATE TABLE offers.promotions (
        promotion_id   BIGSERIAL PRIMARY KEY,
        tenant_id      BIGINT NOT NULL,
        name           VARCHAR(255) NOT NULL,
        description    TEXT,
        discount_type  offers.discount_type_enum NOT NULL,
        discount_value NUMERIC(12,2) NOT NULL DEFAULT 0,
        start_date     DATE NOT NULL,
        end_date       DATE NOT NULL,
        created_at     TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at     TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_promotions_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE offers.promotions IS ''Tabla principal para promociones y descuentos.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.promotion_id IS ''Identificador de la promoción.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.name IS ''Nombre de la promoción.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.description IS ''Descripción de la promoción.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.discount_type IS ''Tipo de descuento: PERCENTAGE, FIXED_AMOUNT, BUY_X_GET_Y.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.discount_value IS ''Valor del descuento (porcentaje o monto).''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.start_date IS ''Fecha de inicio de la promoción.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.end_date IS ''Fecha de fin de la promoción.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotions.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_promotions_update_timestamp
    BEFORE UPDATE ON offers.promotions
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE offers.promotion_product (
        promotion_id BIGINT NOT NULL,
        item_id      BIGINT NOT NULL,
        PRIMARY KEY (promotion_id, item_id),
        CONSTRAINT fk_promoproduct_promotion
          FOREIGN KEY (promotion_id)
          REFERENCES offers.promotions (promotion_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_promoproduct_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE offers.promotion_product IS ''Asocia promociones a productos específicos.''';

    EXECUTE $q$
    CREATE TABLE offers.promotion_taxon (
        promotion_id BIGINT NOT NULL,
        taxon_id     BIGINT NOT NULL,
        PRIMARY KEY (promotion_id, taxon_id),
        CONSTRAINT fk_promotaxon_promotion
          FOREIGN KEY (promotion_id)
          REFERENCES offers.promotions (promotion_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_promotaxon_taxon
          FOREIGN KEY (taxon_id)
          REFERENCES catalog.taxons (taxon_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE offers.promotion_taxon IS ''Asocia promociones a taxons (categorías o subcategorías).''';

    EXECUTE $q$
    CREATE TABLE offers.promotion_rules (
        rule_id      BIGSERIAL PRIMARY KEY,
        promotion_id BIGINT NOT NULL,
        rule_data    JSONB NOT NULL,
        created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_promotion_rules_promotion
          FOREIGN KEY (promotion_id)
          REFERENCES offers.promotions (promotion_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE offers.promotion_rules IS ''Reglas extras (JSON) para promociones.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotion_rules.rule_id IS ''Identificador de la regla de promoción.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotion_rules.promotion_id IS ''FK a offers.promotions.''';
    EXECUTE 'COMMENT ON COLUMN offers.promotion_rules.rule_data IS ''JSONB con condiciones extras (min_amount, max_uses).''';
    EXECUTE 'COMMENT ON COLUMN offers.promotion_rules.created_at IS ''Fecha de creación de la regla.''';


    -- -------------------------------------------------------------------------
    -- 6) SCHEMA: orders
    -- -------------------------------------------------------------------------
    EXECUTE $q$
    CREATE TYPE orders.order_status_enum AS ENUM ('CREATED','PAID','SHIPPED','DELIVERED','CANCELED','REFUNDED')
    $q$;

    EXECUTE $q$
    CREATE TYPE orders.payment_status_enum AS ENUM ('PENDING','COMPLETED','FAILED','REFUNDED')
    $q$;

    EXECUTE $q$
    CREATE TYPE orders.invoice_status_enum AS ENUM ('DRAFT','ISSUED','PAID','CANCELED')
    $q$;

    EXECUTE $q$
    CREATE TYPE orders.return_status_enum AS ENUM ('REQUESTED','APPROVED','DENIED','REFUNDED')
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.cart (
        cart_id    BIGSERIAL PRIMARY KEY,
        tenant_id  BIGINT NOT NULL,
        user_id    BIGINT NOT NULL,
        expires_at TIMESTAMP,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_cart_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_cart_user
          FOREIGN KEY (user_id)
          REFERENCES security.users (user_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.cart IS ''Carrito de compras de un usuario.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart.cart_id IS ''Identificador del carrito.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart.tenant_id IS ''FK al tenant (multi-tenant).''';
    EXECUTE 'COMMENT ON COLUMN orders.cart.user_id IS ''Usuario dueño del carrito.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart.expires_at IS ''Fecha de expiración del carrito.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart.created_at IS ''Fecha de creación del registro.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_cart_update_timestamp
    BEFORE UPDATE ON orders.cart
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.cart_item (
        cart_item_id BIGSERIAL PRIMARY KEY,
        cart_id      BIGINT NOT NULL,
        item_id      BIGINT NOT NULL,
        quantity     INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
        created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_cart_item_cart
          FOREIGN KEY (cart_id)
          REFERENCES orders.cart (cart_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_cart_item_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.cart_item IS ''Productos agregados al carrito.''' ;
    EXECUTE 'COMMENT ON COLUMN orders.cart_item.cart_item_id IS ''Identificador del item en el carrito.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart_item.cart_id IS ''FK a orders.cart.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart_item.item_id IS ''FK a catalog.items (producto).''';
    EXECUTE 'COMMENT ON COLUMN orders.cart_item.quantity IS ''Cantidad de ese producto en el carrito.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart_item.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN orders.cart_item.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_cart_item_update_timestamp
    BEFORE UPDATE ON orders.cart_item
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.order_headers (
        order_id           BIGSERIAL PRIMARY KEY,
        tenant_id          BIGINT NOT NULL,
        user_id            BIGINT NOT NULL,
        shipping_address_id BIGINT,
        billing_address_id  BIGINT,
        status             orders.order_status_enum NOT NULL DEFAULT 'CREATED',
        total_amount       NUMERIC(12,2) NOT NULL DEFAULT 0,
        created_at         TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at         TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_order_headers_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_order_headers_user
          FOREIGN KEY (user_id)
          REFERENCES security.users (user_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_order_shipping_address
          FOREIGN KEY (shipping_address_id)
          REFERENCES common.addresses (address_id)
          ON DELETE SET NULL,
        CONSTRAINT fk_order_billing_address
          FOREIGN KEY (billing_address_id)
          REFERENCES common.addresses (address_id)
          ON DELETE SET NULL
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.order_headers IS ''Encabezado de un pedido (orden).''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.order_id IS ''Identificador del pedido.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.user_id IS ''Usuario que hace el pedido.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.shipping_address_id IS ''Dirección de envío (FK a common.addresses).''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.billing_address_id IS ''Dirección de facturación (FK).''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.status IS ''Estado del pedido (CREATED, PAID, etc.).''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.total_amount IS ''Monto total de la orden.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_headers.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_order_headers_update_timestamp
    BEFORE UPDATE ON orders.order_headers
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.order_lines (
        order_line_id BIGSERIAL PRIMARY KEY,
        order_id      BIGINT NOT NULL,
        item_id       BIGINT NOT NULL,
        quantity      INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
        unit_price    NUMERIC(12,2) NOT NULL DEFAULT 0,
        total_price   NUMERIC(12,2) NOT NULL DEFAULT 0,
        created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_order_lines_order
          FOREIGN KEY (order_id)
          REFERENCES orders.order_headers (order_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_order_lines_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.order_lines IS ''Detalle de productos en la orden.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_lines.order_line_id IS ''Identificador de la línea de pedido.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_lines.order_id IS ''FK a orders.order_headers (pedido).''';
    EXECUTE 'COMMENT ON COLUMN orders.order_lines.item_id IS ''FK a catalog.items (producto).''';
    EXECUTE 'COMMENT ON COLUMN orders.order_lines.quantity IS ''Cantidad pedida (>=1).''';
    EXECUTE 'COMMENT ON COLUMN orders.order_lines.unit_price IS ''Precio unitario.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_lines.total_price IS ''Subtotal (quantity * unit_price).''';
    EXECUTE 'COMMENT ON COLUMN orders.order_lines.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN orders.order_lines.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_order_lines_update_timestamp
    BEFORE UPDATE ON orders.order_lines
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.returns (
        return_id    BIGSERIAL PRIMARY KEY,
        tenant_id    BIGINT NOT NULL,
        order_id     BIGINT NOT NULL,
        user_id      BIGINT NOT NULL,
        item_id      BIGINT NOT NULL,
        reason       TEXT,
        refund_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
        return_date  TIMESTAMP NOT NULL DEFAULT NOW(),
        status       orders.return_status_enum NOT NULL DEFAULT 'REQUESTED',
        created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_returns_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_returns_order
          FOREIGN KEY (order_id)
          REFERENCES orders.order_headers (order_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_returns_user
          FOREIGN KEY (user_id)
          REFERENCES security.users (user_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_returns_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.returns IS ''Registros de devoluciones de productos.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.return_id IS ''Identificador de la devolución.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.order_id IS ''Pedido al que pertenece la devolución.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.user_id IS ''Usuario que solicita la devolución.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.item_id IS ''Producto que se devuelve.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.reason IS ''Motivo de la devolución.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.refund_amount IS ''Cantidad a reembolsar.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.return_date IS ''Fecha en que se inicia la devolución.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.status IS ''Estado de la devolución (REQUESTED, APPROVED, etc.).''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN orders.returns.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_returns_update_timestamp
    BEFORE UPDATE ON orders.returns
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.payment_methods (
        payment_method_id BIGSERIAL PRIMARY KEY,
        tenant_id         BIGINT NOT NULL,
        user_id           BIGINT NOT NULL,
        method_type       VARCHAR(50) NOT NULL,
        token             VARCHAR(255),
        masked_number     VARCHAR(20),
        brand             VARCHAR(50),
        created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at        TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_payment_methods_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_payment_methods_user
          FOREIGN KEY (user_id)
          REFERENCES security.users (user_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.payment_methods IS ''Métodos de pago (tarjetas tokenizadas, etc.).''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.payment_method_id IS ''Identificador del método de pago.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.user_id IS ''Usuario dueño del método de pago.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.method_type IS ''Tipo de método (CREDIT_CARD, PAYPAL, etc.).''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.token IS ''Tokenizado provisto por el PSP.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.masked_number IS ''Número enmascarado (****4242).''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.brand IS ''Marca (VISA, MASTERCARD, etc.).''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment_methods.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_payment_methods_update_timestamp
    BEFORE UPDATE ON orders.payment_methods
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.payment (
        payment_id       BIGSERIAL PRIMARY KEY,
        tenant_id        BIGINT NOT NULL,
        user_id          BIGINT NOT NULL,
        order_id         BIGINT,
        payment_method_id BIGINT,
        transaction_id   VARCHAR(255),
        amount           NUMERIC(12,2) NOT NULL DEFAULT 0,
        status           orders.payment_status_enum NOT NULL DEFAULT 'PENDING',
        created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at       TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_payment_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_payment_user
          FOREIGN KEY (user_id)
          REFERENCES security.users (user_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_payment_order
          FOREIGN KEY (order_id)
          REFERENCES orders.order_headers (order_id)
          ON DELETE SET NULL,
        CONSTRAINT fk_payment_payment_method
          FOREIGN KEY (payment_method_id)
          REFERENCES orders.payment_methods (payment_method_id)
          ON DELETE SET NULL
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.payment IS ''Registro de pagos realizados para una orden.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.payment_id IS ''Identificador del pago.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.user_id IS ''Usuario que paga.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.order_id IS ''Orden a la que se asocia el pago (opcional).''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.payment_method_id IS ''Método de pago usado (FK).''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.transaction_id IS ''ID de la transacción en el PSP.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.amount IS ''Monto pagado.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.status IS ''Estado del pago (PENDING, COMPLETED, etc.).''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN orders.payment.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_payment_update_timestamp
    BEFORE UPDATE ON orders.payment
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.invoice_headers (
        invoice_id    BIGSERIAL PRIMARY KEY,
        tenant_id     BIGINT NOT NULL,
        order_id      BIGINT NOT NULL,
        invoice_number VARCHAR(50) NOT NULL,
        status        orders.invoice_status_enum NOT NULL DEFAULT 'DRAFT',
        total_amount  NUMERIC(12,2) NOT NULL DEFAULT 0,
        issued_at     TIMESTAMP,
        paid_at       TIMESTAMP,
        created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_invoice_headers_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_invoice_headers_order
          FOREIGN KEY (order_id)
          REFERENCES orders.order_headers (order_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.invoice_headers IS ''Encabezado de factura asociada a un pedido.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.invoice_id IS ''Identificador de la factura.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.order_id IS ''Orden asociada a la factura.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.invoice_number IS ''Número de factura.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.status IS ''Estado de la factura (DRAFT, ISSUED, etc.).''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.total_amount IS ''Monto total facturado.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.issued_at IS ''Fecha de emisión de la factura.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.paid_at IS ''Fecha en que se pagó la factura.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_headers.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_invoice_headers_update_timestamp
    BEFORE UPDATE ON orders.invoice_headers
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE orders.invoice_lines (
        invoice_line_id BIGSERIAL PRIMARY KEY,
        invoice_id      BIGINT NOT NULL,
        description     VARCHAR(255),
        quantity        INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
        unit_price      NUMERIC(12,2) NOT NULL DEFAULT 0,
        total_price     NUMERIC(12,2) NOT NULL DEFAULT 0,
        created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_invoice_lines_header
          FOREIGN KEY (invoice_id)
          REFERENCES orders.invoice_headers (invoice_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE orders.invoice_lines IS ''Detalle de conceptos facturados.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_lines.invoice_line_id IS ''Identificador de la línea de factura.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_lines.invoice_id IS ''FK a orders.invoice_headers (factura).''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_lines.description IS ''Descripción o concepto facturado.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_lines.quantity IS ''Cantidad facturada (>=1).''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_lines.unit_price IS ''Precio unitario del concepto facturado.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_lines.total_price IS ''Subtotal (quantity * unit_price).''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_lines.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN orders.invoice_lines.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_invoice_lines_update_timestamp
    BEFORE UPDATE ON orders.invoice_lines
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;


    -- -------------------------------------------------------------------------
    -- 7) SCHEMA: inventory
    -- -------------------------------------------------------------------------
    EXECUTE $q$
    CREATE TABLE inventory.inventory_location (
        location_id BIGSERIAL PRIMARY KEY,
        tenant_id   BIGINT NOT NULL,
        name        VARCHAR(255) NOT NULL,
        address_id  BIGINT,
        created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_location_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_location_address
          FOREIGN KEY (address_id)
          REFERENCES common.addresses (address_id)
          ON DELETE SET NULL
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE inventory.inventory_location IS ''Diferentes bodegas o almacenes (ubicaciones de stock).''';
    EXECUTE 'COMMENT ON COLUMN inventory.inventory_location.location_id IS ''Identificador de la ubicación de inventario.''';
    EXECUTE 'COMMENT ON COLUMN inventory.inventory_location.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN inventory.inventory_location.name IS ''Nombre de la bodega o ubicación.''';
    EXECUTE 'COMMENT ON COLUMN inventory.inventory_location.address_id IS ''FK a common.addresses para ubicación física (opcional).''';
    EXECUTE 'COMMENT ON COLUMN inventory.inventory_location.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN inventory.inventory_location.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_inventory_location_update_timestamp
    BEFORE UPDATE ON inventory.inventory_location
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE inventory.stocks (
        stock_id     BIGSERIAL PRIMARY KEY,
        tenant_id    BIGINT NOT NULL,
        location_id  BIGINT NOT NULL,
        item_id      BIGINT,
        variation_id BIGINT,
        quantity     INT NOT NULL DEFAULT 0,
        created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_stocks_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_stocks_location
          FOREIGN KEY (location_id)
          REFERENCES inventory.inventory_location (location_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_stocks_item
          FOREIGN KEY (item_id)
          REFERENCES catalog.items (item_id)
          ON DELETE SET NULL,
        CONSTRAINT fk_stocks_variation
          FOREIGN KEY (variation_id)
          REFERENCES catalog.variations (variation_id)
          ON DELETE SET NULL
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE inventory.stocks IS ''Cantidad de stock de un producto/variación en una ubicación dada.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stocks.stock_id IS ''Identificador del stock.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stocks.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stocks.location_id IS ''FK a inventory.inventory_location.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stocks.item_id IS ''FK a catalog.items (opcional, si se maneja a nivel producto).''';
    EXECUTE 'COMMENT ON COLUMN inventory.stocks.variation_id IS ''FK a catalog.variations (si se maneja a nivel variación).''';
    EXECUTE 'COMMENT ON COLUMN inventory.stocks.quantity IS ''Cantidad disponible de ese producto/variación en la ubicación.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stocks.created_at IS ''Fecha de creación.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stocks.updated_at IS ''Última actualización.''';

    EXECUTE $q$
    CREATE TRIGGER trg_stocks_update_timestamp
    BEFORE UPDATE ON inventory.stocks
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
    $q$;

    EXECUTE $q$
    CREATE TABLE inventory.stock_movements (
        movement_id  BIGSERIAL PRIMARY KEY,
        tenant_id    BIGINT NOT NULL,
        stock_id     BIGINT NOT NULL,
        movement_type VARCHAR(50) NOT NULL,
        quantity     INT NOT NULL,
        reason       TEXT,
        created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_stock_movements_tenant
          FOREIGN KEY (tenant_id)
          REFERENCES tenants.tenants (tenant_id)
          ON DELETE CASCADE,
        CONSTRAINT fk_stock_movements_stock
          FOREIGN KEY (stock_id)
          REFERENCES inventory.stocks (stock_id)
          ON DELETE CASCADE
    )
    $q$;

    EXECUTE 'COMMENT ON TABLE inventory.stock_movements IS ''Historial de entradas/salidas/ajustes de stock.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stock_movements.movement_id IS ''Identificador del movimiento de stock.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stock_movements.tenant_id IS ''FK al tenant.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stock_movements.stock_id IS ''FK a inventory.stocks.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stock_movements.movement_type IS ''Tipo de movimiento (INBOUND, OUTBOUND, ADJUST...).''';
    EXECUTE 'COMMENT ON COLUMN inventory.stock_movements.quantity IS ''Cantidad movida (puede ser positivo o negativo).''';
    EXECUTE 'COMMENT ON COLUMN inventory.stock_movements.reason IS ''Motivo o descripción del movimiento.''';
    EXECUTE 'COMMENT ON COLUMN inventory.stock_movements.created_at IS ''Fecha en que se registra el movimiento.''';


    -- COMMIT si todo salió bien
    COMMIT;

    RAISE NOTICE 'Creación de esquemas, tipos y tablas finalizada exitosamente.';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'ERROR al crear la estructura. Haciendo ROLLBACK.';
        RAISE NOTICE 'Código de error: %', SQLSTATE;
        RAISE NOTICE 'Mensaje de error: %', SQLERRM;
        ROLLBACK;
    END;

END;
$$ LANGUAGE plpgsql;


-- Otorgar permisos al usuario en todos los schemas (opcional)
GRANT ALL PRIVILEGES ON SCHEMA tenants   TO my_user;
GRANT ALL PRIVILEGES ON SCHEMA security  TO my_user;
GRANT ALL PRIVILEGES ON SCHEMA common    TO my_user;
GRANT ALL PRIVILEGES ON SCHEMA catalog   TO my_user;
GRANT ALL PRIVILEGES ON SCHEMA offers    TO my_user;
GRANT ALL PRIVILEGES ON SCHEMA orders    TO my_user;
GRANT ALL PRIVILEGES ON SCHEMA inventory TO my_user;

-- Otorgar permisos a tablas y secuencias existentes (requieres extension):
-- GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA tenants,security,common,catalog,offers,orders,inventory TO my_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA tenants,security,common,catalog,offers,orders,inventory TO my_user;

-- Fin de ddl.sql
