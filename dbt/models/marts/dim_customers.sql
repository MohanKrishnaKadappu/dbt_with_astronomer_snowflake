with customers as (
    select * from {{ ref('stg_customers') }}
),
orders as (
    select * from {{ ref('stg_orders') }}
),
payments as (
    select * from {{ ref('stg_payments') }}
),
customer_orders as (
    select
        user_id as customer_id,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        count(order_id) as number_of_orders
    from orders
    group by user_id
),
customer_payments as (
    select
        o.user_id as customer_id,
        sum(p.amount) as total_amount
    from orders o
    join payments p on o.order_id = p.order_id
    group by o.user_id
)
select
    c.customer_id,
    c.first_name,
    c.last_name,
    co.first_order_date,
    co.most_recent_order_date,
    co.number_of_orders,
    cp.total_amount as lifetime_value
from customers c
left join customer_orders co on c.customer_id = co.customer_id
left join customer_payments cp on c.customer_id = cp.customer_id
