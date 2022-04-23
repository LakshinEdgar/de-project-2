# Витрина RFM

## 1.1. Выясните требования к целевой витрине.

Постановка задачи выглядит достаточно абстрактно - постройте витрину. Первым делом вам необходимо выяснить у заказчика детали. Запросите недостающую информацию у заказчика в чате.

Зафиксируйте выясненные требования. Составьте документацию готовящейся витрины на основе заданных вами вопросов, добавив все необходимые детали.

-----------

{Впишите сюда ваш ответ}



## 1.2. Изучите структуру исходных данных.

Полключитесь к базе данных и изучите структуру таблиц.

Если появились вопросы по устройству источника, задайте их в чате.

Зафиксируйте, какие поля вы будете использовать для расчета витрины.

-----------

{Впишите сюда ваш ответ}


## 1.3. Проанализируйте качество данных

Изучите качество входных данных. Опишите, насколько качественные данные хранятся в источнике. Так же укажите, какие инструменты обеспечения качества данных были использованы в таблицах в схеме production.

-----------

{Впишите сюда ваш ответ}


## 1.4. Подготовьте витрину данных

Теперь, когда требования понятны, а исходные данные изучены, можно приступить к реализации.

### 1.4.1. Сделайте VIEW для таблиц из базы production.**

Вас просят при расчете витрины обращаться только к объектам из схемы analysis. Чтобы не дублировать данные (данные находятся в этой же базе), вы решаете сделать view. Таким образом, View будут находиться в схеме analysis и вычитывать данные из схемы production. 

Напишите SQL-запросы для создания пяти VIEW (по одному на каждую таблицу) и выполните их. Для проверки предоставьте код создания VIEW.

```SQL
--Впишите сюда ваш ответ
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
### 1.4.2. Напишите DDL-запрос для создания витрины.**

Далее вам необходимо создать витрину. Напишите CREATE TABLE запрос и выполните его на предоставленной базе данных в схеме analysis.

```SQL
--Впишите сюда ваш ответ
DROP TABLE IF EXISTS analysis.dm_rfm_segments;
CREATE TABLE IF NOT EXISTS analysis.dm_rfm_segments (user_id serial,
                                                    recency int,
                                                    frequency int,
                                                    monetary_value int);
```

### 1.4.3. Напишите SQL запрос для заполнения витрины

Наконец, реализуйте расчет витрины на языке SQL и заполните таблицу, созданную в предыдущем пункте.

Для решения предоставьте код запроса.

```SQL
--Впишите сюда ваш ответ
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



