# Проект 1
Опишите здесь поэтапно ход решения задачи. Вы можете ориентироваться на тот план выполнения проекта, который мы предлагаем в инструкции на платформе.!


# Самостоятельный проект
```bash
docker run -d --rm -p 3030:3030 -p 3000:3000 -p 15432:5432 \
--name=de-project-sprint-1-server-local \
sindb/project-sprint-1:latest
```

## Описание проекта
В базе две схемы: production и analysis. В схеме production содержатся оперативные таблицы. В схему analysis необходимо разместить витрину, описание которой представлено ниже.

Заказчик: компания, которая разрабатывает приложение по доставке еды.
Цель проекта: построить витрину для RFM-классификации в схеме analysis. Для анализа нужно отобрать только успешно выполненные заказы (по статусом Closed).
Описание:
  - Наименование витрины: dm_rfm_segments
  - БД: Витрина дожна располагаться в той же базе, что и исходники. 
  - Схема: Витрина дожна располагаться в схеме analysis.
  - Структура: Витрина должна состоять из таких полей:
        user_id
        recency (число от 1 до 5)
        frequency (число от 1 до 5)
        monetary_value (число от 1 до 5)
  - Глубина данных: с начала 2021 года
  - Частота обновления данных: обновления не нужны

## Проверка качества данных
- доступы ко всем таблицам есть
- все колонки на месте

```SQL
SELECT *
FROM pg_catalog.pg_tables
WHERE schemaname = 'production' AND tablename IN ('orderitems','orders','orderstatuses','orderstatuslog','products','users');
```

- В таблице orders данные только за 2 месяца февраль и март 2022 года
```SQL
SELECT EXTRACT (YEAR FROM order_ts) order_ts_date,
       EXTRACT (month FROM order_ts) order_ts_date,
       SUM(payment)
FROM production.orders vo
GROUP BY 1,
         2
```

- Месяцы тоже неполные. Заказы начинаются с середины февраля и заканчиваются в середине марта
```SQL
SELECT DATE_TRUNC('day',order_ts)::DATE as order_ts_date,
       COUNT(user_id),
       SUM(PAYMENT)
FROM  production.orders vo
LEFT JOIN production.orderstatuses vo2 on vo2.id = vo.status
WHERE vo2.key='Closed' AND EXTRACT (YEAR FROM order_ts)>=2021
GROUP BY 1
```

- Минимальное значение суммы заказа сильно отличается от среднего значения, но в динамике оно постоянное. Динамика среднtего значения и максимального сильно не меняется.
Значения NULL отсутствуют в колонках user_id, order_id, status 
```SQL
WITH cte AS (SELECT user_id,
                    order_id,
                    status,
                    DATE_TRUNC('day',order_ts)::DATE as order_ts_date,
                    SUM(PAYMENT) AS sum_payment
       FROM  production.orders vo
       LEFT JOIN production.orderstatuses vo2 ON vo2.id = vo.status
       WHERE vo2.key='Closed' AND EXTRACT (YEAR FROM order_ts)>=2021
       GROUP BY 1,2,3,4)
SELECT order_ts_date,
       SUM(sum_payment)/COUNT(order_id) AS avg_order,
       MIN(sum_payment) AS sum_payment_min,
       MAX(sum_payment) AS sum_payment_max,
       AVG(sum_payment) AS sum_payment_avg,
       COUNT(CASE WHEN user_id IS NULL THEN 1 END) AS user_id_null,
       COUNT(CASE WHEN order_id IS NULL THEN 1 END) AS order_idnull,
       COUNT(CASE WHEN status IS NULL THEN 1 END) AS order_idnull
FROM cte
GROUP BY 1;
```

## Создание представлений
```SQL 
DROP VIEW IF EXISTS analysis.v_orders;
CREATE VIEW analysis.v_orders AS
SELECT order_id,
       order_ts,
       user_id,
       bonus_payment,
       payment,
       cost,
       bonus_grant,
       status
FROM production.orders;
```

```SQL
DROP VIEW IF EXISTS analysis.v_orderitems;
CREATE VIEW analysis.v_orderitems AS
SELECT id,
       product_id,
       order_id,
       name,
       price,
       discount,
       quantity
FROM production.orderitems;
```

```SQL
DROP VIEW IF EXISTS analysis.v_orderstatuses;
CREATE VIEW analysis.v_orderstatuses AS
SELECT id,
       key
FROM production.orderstatuses;
```

```SQL
DROP VIEW IF EXISTS analysis.v_products;
CREATE VIEW analysis.v_products AS
SELECT id,
       name,
       price
FROM production.products;
```

```SQL
DROP VIEW IF EXISTS analysis.v_users;
CREATE VIEW analysis.v_users
AS
SELECT id,
       name,
       login
FROM production.users;
```

## Создание витрины
```SQL
DROP TABLE IF EXISTS analysis.dm_rfm_segments;
CREATE TABLE IF analysis.dm_rfm_segments (user_id serial PRIMARY KEY,
                                                    recency int CHECK (recency BETWEEN 1 AND 5),
                                                    frequency int CHECK (frequency BETWEEN 1 AND 5),
                                                    monetary_value int (monetary_value BETWEEN 1 AND 5));
```

## Наполнение витрины
```SQL
with prev_ord as (SELECT order_id,
                         user_id,
                         order_ts::DATE AS order_ts_date,
                         LAG(order_ts::DATE,1,order_ts::DATE) OVER (PARTITION BY user_id ORDER BY order_ts::DATE) AS prev_order_date,
                         PAYMENT
                  FROM analysis.v_orders vo
                  LEFT JOIN analysis.v_orderstatuses vo2 ON vo2.id = vo.status
                  WHERE vo2.key='Closed' AND EXTRACT (YEAR FROM order_ts)>=2021),
rfm_raw as (SELECT user_id,
                    MAX(order_ts_date)- MAX(prev_order_date) AS R,
                    COUNT(*) as F,
                    AVG(PAYMENT) AS M
            FROM prev_ord po
            GROUP BY 1)
INSERT INTO analysis.dm_rfm_segments (user_id,
                                      recency,
                                      frequency,
                                      monetary_value)
SELECT user_id,
       NTILE(5) OVER (ORDER BY R DESC) recency,
       NTILE(5) OVER (ORDER BY F ASC) as frequency,
       NTILE(5) OVER (ORDER BY M ASC) as monetary_value
FROM rfm_raw;
```

## Создание представления после изменений команды Backend
```SQL
DROP VIEW IF EXISTS analysis.v_orderstatuslog;
CREATE VIEW analysis.v_orderstatuslog AS
SELECT id,
       order_id ,
       status_id,
       dttm 
FROM production.orderstatuslog;
```

## Наполнение витрины после изменений команды Backend
```SQL
TRUNCATE TABLE analysis.dm_rfm_segments;          
WITH lsd AS (SELECT order_id,
                    max(dttm) AS last_st_date
             FROM analysis.v_orderstatuslog
             GROUP BY 1),
prev_ord AS (SELECT vo.order_id,
                    user_id,
                    order_ts::DATE AS order_ts_date,
                    LAG(order_ts::DATE,1,order_ts::DATE) OVER (PARTITION BY user_id ORDER BY order_ts::DATE) AS prev_order_date,
                    PAYMENT
             FROM analysis.v_orders vo
             INNER JOIN lsd ON vo.order_id=lsd.order_id
             LEFT JOIN analysis.v_orderstatuses vo2 ON vo2.id = vo.status
             WHERE vo2.key='Closed' AND EXTRACT (YEAR FROM order_ts)>=2021),
rfm_raw AS (SELECT user_id,
                   MAX(order_ts_date)- MAX(prev_order_date) AS R,
                   COUNT(*) AS F,
                   AVG(PAYMENT) AS M
            FROM prev_ord po
            GROUP BY 1)
INSERT INTO analysis.dm_rfm_segments (user_id,
                                      recency,
                                      frequency,
                                      monetary_value)            
SELECT user_id,
       NTILE(5) OVER (ORDER BY R DESC) recency,
       NTILE(5) OVER (ORDER BY F ASC) as frequency,
       NTILE(5) OVER (ORDER BY M ASC) as monetary_value
FROM rfm_raw;
```


