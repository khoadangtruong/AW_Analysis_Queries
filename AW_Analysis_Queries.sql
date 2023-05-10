USE mavenfuzzyfactory;

-- =======================================================================================================
-- ====================================== Analyzing Traffic Source =======================================
-- =======================================================================================================

-- 1. Finding Top Traffic Source
SELECT 
	utm_source,
    utm_campaign,
    http_referer,
    COUNT(DISTINCT website_session_id) AS total_sessions
FROM website_sessions
WHERE created_at < '2012-04-12'
GROUP BY 1, 2, 3
ORDER BY total_sessions;

-- 2. Traffic Source Conv Rate
SELECT 
	COUNT(DISTINCT a.website_session_id) AS sessions,
    COUNT(DISTINCT b.order_id) AS orders,
    COUNT(DISTINCT b.order_id) / COUNT(DISTINCT a.website_session_id) AS session_to_order_conv_rt
FROM website_sessions a
LEFT JOIN orders b
	ON a.website_session_id = b.website_session_id
WHERE a.created_at < '2012-04-14'
	AND a.utm_source = 'gsearch'
    AND a.utm_campaign = 'nonbrand';

-- 3. Traffic Source Trending
SELECT 
	MIN(DATE(created_at)) AS start_of_week,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions 
WHERE created_at < '2012-05-10'
	AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY YEARWEEK(created_at); 

-- 4. Bid Optimization For Paid Traffic
-- Session to order conv rate by device type
SELECT 
	a.device_type,
    COUNT(DISTINCT a.website_session_id) AS sessions,
    COUNT(DISTINCT b.order_id) AS orders,
    COUNT(DISTINCT b.order_id) / COUNT(DISTINCT a.website_session_id) AS session_to_order_conv_rt
FROM website_sessions a
LEFT JOIN orders b
	ON a.website_session_id = b.website_session_id
WHERE a.created_at < '2012-05-11'
GROUP BY 1;

-- 5. Trending w/Granular Segments
-- Weekly session volumn by device type
SELECT 
	MIN(DATE(created_at)) AS start_of_week,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN website_session_id ELSE NULL END) AS desktop_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id ELSE NULL END) AS mobile_sessions
FROM website_sessions
WHERE created_at < '2012-06-09'
GROUP BY YEARWEEK(created_at);


-- =======================================================================================================
-- ==================================== Analyzing Website Performance ====================================
-- =======================================================================================================

-- 1. Finding Top Website Pages
SELECT 
	pageview_url,
	COUNT(DISTINCT website_session_id) AS sessions 
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY 1
ORDER BY sessions DESC;

-- 2. Finding Top Entry Pages
CREATE TEMPORARY TABLE sessions_w_first_pageview
SELECT 
	website_session_id,
    MIN(website_pageview_id) AS first_pv
FROM website_pageviews
WHERE created_at < '2012-06-12'
GROUP BY 1;

SELECT 
	b.pageview_url AS landing_page,
    COUNT(DISTINCT a.website_session_id) AS session_hitting_page
FROM sessions_w_first_pageview a
JOIN website_pageviews b
	ON a.first_pv = b.website_pageview_id
GROUP BY 1;

-- Calculate Bounce Rate For /home
CREATE TEMPORARY TABLE bounced_sessions
SELECT 
	a.website_session_id,
    COUNT(DISTINCT b.website_pageview_id) AS total_pv
FROM sessions_w_first_pageview a
LEFT JOIN website_pageviews b
	ON a.website_session_id = b.website_session_id
GROUP BY 1
HAVING total_pv = 1;

SELECT 
	COUNT(DISTINCT a.website_session_id) AS sessions,
    COUNT(DISTINCT b.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT b.website_session_id) / COUNT(DISTINCT a.website_session_id) AS bounce_rate
FROM sessions_w_first_pageview a
LEFT JOIN bounced_sessions b
	ON a.website_session_id = b.website_session_id;

-- 3. Analyzing Landing Pages Test
-- A/B testing for /home & /lander-1 
-- with utm_source = gsearch & utm_campaign = nonbrand
SELECT 
	MIN(created_at) AS first_created,
    MIN(website_pageview_id) AS first_pageview
FROM website_pageviews
WHERE pageview_url = '/lander-1'
	AND created_at IS NOT NULL;
-- lander-1 first pageview : 23504

CREATE TEMPORARY TABLE first_pageview_test
SELECT 
	a.website_session_id,
    MIN(b.website_pageview_id) AS first_pv
FROM website_sessions a
JOIN website_pageviews b
	ON a.website_session_id = b.website_session_id
WHERE b.website_pageview_id > 23504
	AND a.created_at < '2012-07-28'
    AND a.utm_source = 'gsearch'
    AND a.utm_campaign = 'nonbrand'
GROUP BY 1;

CREATE TEMPORARY TABLE sessions_w_landing_page_url_test
SELECT 
	a.website_session_id,
    b.pageview_url AS landing_page
FROM first_pageview_test a
JOIN website_pageviews b
	ON a.first_pv = b.website_pageview_id;

CREATE TEMPORARY TABLE bounced_sessions_test
SELECT 
	a.website_session_id,
    COUNT(DISTINCT website_pageview_id) AS total_views
FROM sessions_w_landing_page_url_test a
LEFT JOIN website_pageviews b
	ON a.website_session_id = b.website_session_id
GROUP BY 1
HAVING total_views = 1;

SELECT 
	a.landing_page,
    COUNT(DISTINCT a.website_session_id) AS sessions,
    COUNT(DISTINCT b.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT b.website_session_id) / COUNT(DISTINCT a.website_session_id) AS bounce_rate
FROM sessions_w_landing_page_url_test a
LEFT JOIN bounced_sessions_test b
	ON a.website_session_id = b.website_session_id
GROUP BY 1;

-- 4. Landing Pages Trend Analysis
-- Retrieve sessions, bounced sessions & bounce rate for '/home' & '/lander-1'
CREATE TEMPORARY TABLE session_w_first_pv_and_pv_count
SELECT 
	a.website_session_id,
    MIN(b.website_pageview_id) AS first_pv,
    COUNT(b.website_pageview_id) AS total_views
FROM website_sessions a
LEFT JOIN website_pageviews b
	ON a.website_session_id = b.website_session_id
WHERE a.created_at >= '2012-06-01'
	AND a.created_at < '2012-08-31'
	AND a.utm_source = 'gsearch'
    AND a.utm_campaign = 'nonbrand'
GROUP BY 1;

CREATE TEMPORARY TABLE session_landing_page_url_and_date
SELECT 
	a.website_session_id,
    a.first_pv,
    a.total_views,
    b.pageview_url,
    b.created_at
FROM session_w_first_pv_and_pv_count a
JOIN website_pageviews b
	ON a.website_session_id = b.website_session_id
WHERE b.pageview_url IN('/home', '/lander-1');

SELECT 
	MIN(DATE(created_at)) AS start_of_week,
    COUNT(DISTINCT CASE WHEN total_views = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) AS bounce_rate,
    COUNT(DISTINCT CASE WHEN pageview_url = '/home' THEN website_session_id ELSE NULL END) AS home_sessions,
    COUNT(DISTINCT CASE WHEN pageview_url = '/lander-1' THEN website_session_id ELSE NULL END) AS lander1_sessions
FROM session_landing_page_url_and_date
GROUP BY YEARWEEK(created_at);

-- 4. Building Conversion Funels
-- Start from '/lander-1' to '/thank-you-for-your-order'
-- With utm_source = gsearch & utm_campaign = nonbrand

-- /products
-- /the-original-mr-fuzzy
-- /cart
-- /shipping
-- /billing
CREATE TEMPORARY TABLE sessions_w_conversion_path_flag
SELECT 
	website_session_id,
    MAX(product_flag) AS product_made_it,
    MAX(mrfuzzy_flag) AS mrfuzzy_made_it,
    MAX(cart_flag) AS cart_made_it,
    MAX(shipping_flag) AS shipping_made_it,
    MAX(billing_flag) AS billing_made_it,
    MAX(thankyou_flag) AS thankyou_made_it
FROM (
SELECT 
	a.website_session_id,
    CASE WHEN b.pageview_url = '/products' THEN 1 ELSE 0 END AS product_flag,
    CASE WHEN b.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_flag,
    CASE WHEN b.pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_flag,
    CASE WHEN b.pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_flag,
    CASE WHEN b.pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_flag,
    CASE WHEN b.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_flag
FROM website_sessions a
LEFT JOIN website_pageviews b
	ON a.website_session_id = b.website_session_id
WHERE a.created_at > '2012-08-05'
	AND a.created_at < '2012-09-05'
    AND a.utm_source = 'gsearch'
    AND a.utm_campaign = 'nonbrand'
) AS T
GROUP BY 1;

SELECT 
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS to_product,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou,
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) AS lander_clickthrough_rt,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS product_clickthrough_rt,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS mrfuzzy_clickthrough_rt,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_clickthrough_rt,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) shipping_clickthrough_rt,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) billing_clickthrough_rt
FROM sessions_w_conversion_path_flag;

-- 4. Analyzing Conversion Funel Tests
-- Billing & Billing-2 Performance (session, order, session to order conv rate)
CREATE TEMPORARY TABLE billing_version_w_sessions_and_orders
SELECT 
	a.pageview_url AS billing_versions,
    a.website_session_id,
    b.order_id
FROM website_pageviews a
LEFT JOIN orders b
	ON a.website_session_id = b.website_session_id
WHERE a.pageview_url IN ('/billing', '/billing-2');

SELECT 
	billing_versions AS billing_version_seen,
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT ordeR_id) AS orders,
    COUNT(DISTINCT ordeR_id) / COUNT(DISTINCT website_session_id) AS billing_to_order_rt
FROM billing_version_w_sessions_and_orders
GROUP BY 1;


-- ==========================================================================================
-- ==================================== Product Analysis ====================================
-- ==========================================================================================

-- 1. Product-level Sales Analysis
-- Monthly trend for number of sales, total revenue and total margin
SELECT 
	YEAR(created_at) AS yr,
    MONTH(created_at) AS mo,
    COUNT(DISTINCT order_id) AS number_of_sales,
    SUM(price_usd) AS total_revenue,
    SUM(price_usd - cogs_usd) AS total_margin
FROM orders 
WHERE created_at < '2013-01-04'
GROUP BY 1, 2;

-- 2. Analyzing Product Launches
-- Monthly order volumn, session to order conv rt, revenue per session, prod 1 & 2 order

SELECT 
	YEAR(a.created_at) AS yr,
    MONTH(a.created_at) AS mo,
    COUNT(DISTINCT b.order_id) AS orders,
    COUNT(DISTINCT b.order_id) / COUNT(DISTINCT a.website_session_id) AS session_to_order_conv_rt,
    SUM(price_usd) / COUNT(DISTINCT a.website_session_id) AS revenue_per_session,
    COUNT(DISTINCT CASE WHEN primary_product_id = 1 THEN b.order_id ELSE NULL END) AS prod1_orders,
    COUNT(DISTINCT CASE WHEN primary_product_id = 2 THEN b.order_id ELSE NULL END) AS prod2_orders
FROM website_sessions a
LEFT JOIN orders b
	ON a.website_session_id = b.website_session_id
WHERE a.created_at > '2012-04-01'
	AND a.created_at < '2013-04-05'
GROUP BY 1, 2;

-- 3. Product-level Website Pathing
CREATE TEMPORARY TABLE sessions_w_time_period
SELECT 
	website_session_id,
    website_pageview_id,
    CASE 
		WHEN created_at < '2013-01-06' THEN 'A.Pre_Product_2'
        ELSE 'B.Post_Product_2'
	END AS time_period
FROM website_pageviews
WHERE created_at > '2012-10-06'
	AND created_at < '2013-04-06'
    AND pageview_url = '/products';
    
CREATE TEMPORARY TABLE sessions_w_min_next_pv
SELECT 
	a.time_period,
	a.website_session_id,
    MIN(b.website_pageview_id) AS min_next_pv
FROM sessions_w_time_period a
LEFT JOIN website_pageviews b
	ON a.website_session_id = b.website_session_id
    AND b.website_pageview_id > a.website_pageview_id
GROUP BY 1, 2;

CREATE TEMPORARY TABLE sessions_w_min_next_pv_url
SELECT 
	a.time_period,
    a.website_session_id,
    b.pageview_url AS landing_page
FROM sessions_w_min_next_pv a
LEFT JOIN website_pageviews b
	ON a.min_next_pv = b.website_pageview_id;

SELECT 
	time_period,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN landing_page IS NOT NULL THEN website_session_id ELSE NULL END) AS w_next_pg,
    COUNT(DISTINCT CASE WHEN landing_page IS NOT NULL THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) AS pct_w_next_pg,
    COUNT(DISTINCT CASE WHEN landing_page = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN landing_page = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) AS pct_to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN landing_page = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) AS to_lovebear,
    COUNT(DISTINCT CASE WHEN landing_page = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) AS pct_to_lovebear
FROM sessions_w_min_next_pv_url
GROUP BY 1;

-- 4. Building Product-level Conversion Funels
-- Compare session volumn from mrfuzzy and lovebear to cart, shipping, billing, thank you

SELECT 
	MIN(created_at) AS first_launched
FROM website_pageviews
WHERE pageview_url = '/the-forever-love-bear';

-- Product 2 first launched: 2013-01-06

CREATE TEMPORARY TABLE sessions_w_product_page_seen
SELECT 
	website_session_id,
    website_pageview_id,
    pageview_url AS product_page_seen
FROM website_pageviews
WHERE created_at > '2013-01-06' 
	AND created_at < '2013-04-10'
	AND pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear');

-- /cart
-- /shipping
-- /billing-2
-- /thank-you-for-your-order
CREATE TEMPORARY TABLE sessions_w_landing_page_seen
SELECT 
	website_session_id,
	CASE 
		WHEN product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
        WHEN product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
        ELSE 'Something Wrong'
	END AS product_seen,
    landing_page
FROM (
SELECT 
    a.website_session_id,
    a.product_page_seen,
    b.pageview_url AS landing_page
FROM sessions_w_product_page_seen a
LEFT JOIN website_pageviews b
	ON a.website_session_id = b.website_session_id
    AND b.website_pageview_id > a.website_pageview_id
) AS T;

SELECT 
	product_seen,
	COUNT(DISTINCT website_session_id) AS sessions,
	COUNT(DISTINCT CASE WHEN landing_page = '/cart' THEN website_session_id ELSE NULL END) AS to_cart,
	COUNT(DISTINCT CASE WHEN landing_page = '/shipping' THEN website_session_id ELSE NULL END) AS to_shipping,
	COUNT(DISTINCT CASE WHEN landing_page = '/billing-2' THEN website_session_id ELSE NULL END) AS to_billing,
	COUNT(DISTINCT CASE WHEN landing_page = '/thank-you-for-your-order' THEN website_session_id ELSE NULL END) AS to_thankyou
FROM sessions_w_landing_page_seen
GROUP BY 1;

SELECT 
	product_seen,
	COUNT(DISTINCT CASE WHEN landing_page = '/cart' THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT website_session_id) AS product_to_cart_rt,
	COUNT(DISTINCT CASE WHEN landing_page = '/shipping' THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN landing_page = '/cart' THEN website_session_id ELSE NULL END) AS cart_to_shipping_rt,
	COUNT(DISTINCT CASE WHEN landing_page = '/billing-2' THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN landing_page = '/shipping' THEN website_session_id ELSE NULL END) AS shipping_to_billing_rt,
	COUNT(DISTINCT CASE WHEN landing_page = '/thank-you-for-your-order' THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN landing_page = '/billing-2' THEN website_session_id ELSE NULL END) AS billing_to_thankyou_rt
FROM sessions_w_landing_page_seen
GROUP BY 1;

-- 5. Cross Sell Analysis
SELECT 
	a.primary_product_id AS product,
    COUNT(DISTINCT CASE WHEN b.product_id = 1 THEN a.order_id ELSE NULL END ) AS xsold_p1,
    COUNT(DISTINCT CASE WHEN b.product_id = 2 THEN a.order_id ELSE NULL END ) AS xsold_p2,
    COUNT(DISTINCT CASE WHEN b.product_id = 3 THEN a.order_id ELSE NULL END ) AS xsold_p3,
    COUNT(DISTINCT CASE WHEN b.product_id = 4 THEN a.order_id ELSE NULL END ) AS xsold_p4
FROM orders a
LEFT JOIN order_items b
	ON a.order_id = b.order_id
    AND b.is_primary_item = 0
GROUP BY 1;

SELECT 
	a.primary_product_id AS product,
    COUNT(DISTINCT CASE WHEN b.product_id = 1 THEN a.order_id ELSE NULL END ) / COUNT(DISTINCT a.order_id) AS p1_xsold_rt,
    COUNT(DISTINCT CASE WHEN b.product_id = 2 THEN a.order_id ELSE NULL END ) / COUNT(DISTINCT a.order_id) AS p2_xsold_rt,
    COUNT(DISTINCT CASE WHEN b.product_id = 3 THEN a.order_id ELSE NULL END ) / COUNT(DISTINCT a.order_id) AS p3_xsold_rt,
    COUNT(DISTINCT CASE WHEN b.product_id = 4 THEN a.order_id ELSE NULL END ) / COUNT(DISTINCT a.order_id) AS p4_xsold_rt
FROM orders a
LEFT JOIN order_items b
	ON a.order_id = b.order_id
    AND b.is_primary_item = 0
GROUP BY 1;












