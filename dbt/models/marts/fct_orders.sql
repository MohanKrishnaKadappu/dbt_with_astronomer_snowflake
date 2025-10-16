with orders as (
    select * from {{ ref('stg_orders') }}
),
payments as (
    select * from {{ ref('stg_payments') }}
),
order_payments as (
    select
        order_id,
        sum(case when payment_method = 'credit_card' then amount else 0 end) as credit_card_amount,
        sum(case when payment_method = 'coupon' then amount else 0 end) as coupon_amount,
        sum(case when payment_method = 'bank_transfer' then amount else 0 end) as bank_transfer_amount,
        sum(case when payment_method = 'gift_card' then amount else 0 end) as gift_card_amount,
        sum(amount) as total_amount
    from payments
    group by order_id
)
select
    o.order_id,
    o.user_id as customer_id,
    o.order_date,
    o.status,
    p.credit_card_amount,
    p.coupon_amount,
    p.bank_transfer_amount,
    p.gift_card_amount,
    p.total_amount as amount
from orders o
left join order_payments p
    on o.order_id = p.order_id
