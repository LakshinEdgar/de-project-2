DROP TABLE IF EXISTS public.d_user_payment_log;
DROP TABLE IF EXISTS public.d_user_activity_log;
DROP TABLE IF EXISTS public.f_sales;
DROP TABLE IF EXISTS public.d_clients CASCADE;
DROP TABLE IF EXISTS public.d_buckets;
DROP TABLE IF EXISTS public.d_orders CASCADE;
DROP TABLE IF EXISTS public.d_products CASCADE;
DROP TABLE IF EXISTS public.d_vendors CASCADE;
DROP TABLE IF EXISTS public.d_categories CASCADE;

CREATE TABLE public.d_clients (
client_id BIGINT,
first_name TEXT,
last_name TEXT,
utm_campaign VARCHAR(30),
PRIMARY KEY (client_id)
);
CREATE INDEX client_id_index ON public.d_clients(client_id);

CREATE TABLE public.d_user_payment_log (
payment_log_id BIGINT,
client_id BIGINT,
hit_date_time TIMESTAMP,
action VARCHAR(20),
payment_amount NUMERIC(14,2),
PRIMARY KEY (payment_log_id),
FOREIGN KEY (client_id) REFERENCES d_clients(client_id) ON UPDATE cascade
);
CREATE INDEX user_payment_log_id_index ON public.d_user_payment_log(payment_log_id);

CREATE TABLE public.d_user_activity_log  (
activity_id BIGINT,
client_id BIGINT,
hit_date_time TIMESTAMP,
action VARCHAR(20),
PRIMARY KEY (activity_id),
FOREIGN KEY (client_id) REFERENCES public.d_clients(client_id) ON UPDATE cascade
);
CREATE INDEX user_activity_id_index ON public.d_user_activity_log(activity_id);

CREATE TABLE public.d_vendors (
id SERIAL,
vendor_id BIGINT,
name_vendor TEXT,
description TEXT,
PRIMARY KEY (id)
);
CREATE INDEX vendor_id_index ON public.d_vendors (vendor_id);

CREATE TABLE public.d_categories (
category_id BIGINT,
name_category TEXT,
description TEXT,
PRIMARY KEY (category_id)
);
CREATE INDEX category_id_index ON public.d_categories (category_id);

CREATE TABLE public.d_products (
product_id BIGINT,
category_id BIGINT,
vendor_id BIGINT,
name_product TEXT,
description TEXT,
stock boolean,
PRIMARY KEY (product_id),
FOREIGN KEY (category_id) REFERENCES public.d_categories(category_id) ON UPDATE cascade,
FOREIGN KEY (vendor_id) REFERENCES public.d_vendors(id) ON UPDATE cascade
);
CREATE INDEX product_id_index ON public.d_products (product_id);

CREATE TABLE public.d_orders (
order_id BIGINT,
payment NUMERIC(14,2),
hit_date_time TIMESTAMP,
PRIMARY KEY (order_id)
);
CREATE INDEX order_id_index ON public.d_orders(order_id);

CREATE TABLE public.d_buckets (
bucked_id BIGINT,
order_id BIGINT,
product_id BIGINT,
num NUMERIC(14,2),
PRIMARY KEY (bucked_id),
FOREIGN KEY (product_id) REFERENCES public.d_products(product_id) ON UPDATE CASCADE,
FOREIGN KEY (order_id) REFERENCES public.d_orders(order_id) ON UPDATE CASCADE
);
CREATE INDEX bucket_id_index ON public.d_buckets(bucked_id);

CREATE TABLE public.f_sales (
sale_id BIGINT,
order_id BIGINT,
client_id BIGINT,
promotion_id BIGINT,
PRIMARY KEY (sale_id),
FOREIGN KEY (order_id) REFERENCES public.d_orders(order_id) ON UPDATE cascade,
FOREIGN KEY (client_id) REFERENCES public.d_clients(client_id) ON UPDATE cascade
);
CREATE INDEX sales_order_id_index ON public.f_sales(order_id);
