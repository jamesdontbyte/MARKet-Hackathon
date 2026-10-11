-- Sample data. Coordinates are PLACEHOLDERS near the demo zone center (10.7525111, 121.9413404).
-- Kape Tahanan (the DEMO SHOP) uses its real coordinates. The other three are placeholders;
-- replace with real ones when known (must stay inside the 1500 m circle).
insert into businesses (id, owner_id, name, category, subtitle, bio, address, hours, lat, lng, rating, verified) values
 ('00000000-0000-0000-0000-000000000001', null, 'Kape Tahanan', 'cafe', 'Café & Bakery',
  'Artisan pour-over coffee, ube macapuno basque cake, and fresh sourdough pastries.', 'San Jose, Antique', 'Mon–Sun 7:30 AM – 9:00 PM', 10.754707481558897, 121.93442817768808, 4.9, true),
 ('00000000-0000-0000-0000-000000000002', null, 'Antique Weaves & Crafts', 'retail', 'Retail & Artisans',
  'Traditional handwoven Patadyong textiles and local bamboo souvenirs.', 'San Jose, Antique', 'Mon–Sat 9:00 AM – 6:00 PM', 10.7510, 121.9400, 4.8, true),
 ('00000000-0000-0000-0000-000000000003', null, 'Madre Cacao Garden Bistro', 'food', 'Food & Dining',
  'Garden bistro serving local cacao desserts and native Antique dishes.', 'San Jose, Antique', 'Daily 10:00 AM – 11:00 PM', 10.7545, 121.9385, 4.7, true),
 ('00000000-0000-0000-0000-000000000004', null, 'Isla Verde Grooming & Barber', 'salon', 'Salons & Barbershops',
  'Classic cuts and grooming.', 'Gov. Villavert St., San Jose', 'Mon–Sat 9:00 AM – 8:00 PM', 10.7500, 121.9435, 4.6, true)
on conflict (id) do nothing;

insert into products (business_id, name, price, category, description) values
 ('00000000-0000-0000-0000-000000000001','Sea Salt Caramel Latte',180,'Beverages','Best seller'),
 ('00000000-0000-0000-0000-000000000001','Almond Flaky Croissant',145,'Pastries','Freshly baked today'),
 ('00000000-0000-0000-0000-000000000001','Single Origin Pour-over',160,'Beverages','Benguet Arabica, light roast'),
 ('00000000-0000-0000-0000-000000000001','Ube Macapuno Basque Cake',220,'Pastries','Limited slices daily');

insert into promos (business_id, title, description, promo_type, value_label, ends_at, redeem_limit, redeemed_count) values
 ('00000000-0000-0000-0000-000000000001','Buy 1 Take 1 Afternoon Coffee Hour','Any signature coffee, 2 PM – 5 PM.','bogo','BOGO', now() + interval '2 days', 100, 72),
 ('00000000-0000-0000-0000-000000000001','Pastry & Brew Combo','15% off pour-over + croissant.','percent','15% OFF', now() + interval '5 days', 100, 46),
 ('00000000-0000-0000-0000-000000000002','20% Off Handcrafted Loom Bags','Handwoven bags, while supplies last.','percent','-20%', now() + interval '6 days', 50, 12),
 ('00000000-0000-0000-0000-000000000003','P100 Off Min. Spend P800','Ends tonight 11:59 PM.','amount_off','HOT', now() + interval '8 hours', 30, 9);
