# SADEE PRO STORE — Gaming Store Update

Premium dark gaming storefront with neon-red styling, responsive product cards, wishlist, stock visibility, customer order lookup, eZ Cash manual verification, license delivery, promo codes, announcements, reviews moderation, website customization, and a separate admin console.

## Included in this build

- Gaming-style black / neon-red storefront with responsive layout and reduced-motion support.
- Product search, category filters, plans, product detail modal, stock visibility, and device-local wishlist.
- Customer order submission using a server-side function; the displayed order code is used with the customer's email in **Order Status**.
- eZ Cash manual verification: the admin must check the actual transaction before verifying. The admin enters the exact license key after verification; no key is auto-generated.
- License key appears in Order Status only after payment verification and after the admin saves the supplied key; email delivery is attempted using Resend when configured.
- `supabase/fix-stock-and-order-status.sql` sets active products to 999 stock and installs the secure stock-decrement function used during payment verification.
- Admin product add/edit/delete and product-image upload through a secret-protected Netlify Function.
- Admin overview cards for products, low stock, orders and verified sales (orders/sales cards are based on the most recent 100 orders returned by the function).
- Site customizer for logo image, hero image, hero video and accent color.
- Promo code creation and checkout discount validation.
- Announcements/maintenance notices and customer review submission with admin approval.
- PWA manifest and basic offline shell caching.

## Before deploying

**This ZIP has not been connected to your live Supabase or Netlify account, and has not been deployed.** Do not assume that payments, email, database policies or the live site have been verified. Run the setup below and test with a small test order before announcing it to customers.

### 1. Supabase

1. Open the Supabase SQL Editor for the project configured in `config.js`.
2. Run `supabase/schema.sql`.
3. Run `supabase/orders-schema.sql`.
4. Confirm the `product-images` storage bucket exists and is public-read only. The SQL removes anonymous upload/update/delete policies; uploads are done server-side.
5. Check that your products table uses the fields defined in `schema.sql` and edit the sample listing before publishing.

### 2. Netlify environment variables

Add these under Netlify site settings → Environment variables. Never add the service-role key or admin secret to `config.js` or commit them to GitHub.

- `SUPABASE_URL` — your Supabase project URL.
- `SUPABASE_SERVICE_ROLE_KEY` — the Supabase service-role key; server-side only.
- `STORE_ADMIN_SECRET` — a long, random private value. You enter it in the admin prompt when performing protected actions.
- `RESEND_API_KEY` — optional; required for automatic email delivery.
- `STORE_FROM_EMAIL` — optional; a sender address verified with Resend.

Redeploy after adding or changing environment variables. Functions require Node.js support; the included `netlify.toml` sets the functions directory to `netlify/functions`.

### 3. Store configuration

Edit `config.js` and set the correct public Supabase URL and publishable/anon key, the official `EZCASH_NUMBER`, and your WhatsApp number. The eZ Cash number is intentionally blank until the store owner provides the real number. Do not invent it. `SUPPORT_EMAIL` is a placeholder and should be replaced with a real support email or left unused.

### 4. eZ Cash and licenses

1. Customer submits an order code, email and payment reference.
2. Admin checks the actual incoming eZ Cash transaction outside the website.
3. Admin first verifies the actual payment. After verification, the admin enters the exact customer license key in the Orders panel and saves it; only then is the key shown in Order Status. The key is not auto-generated.
4. The customer uses **Order Status** with the order code and matching email to see the status and key. Email is sent only when Resend settings are valid.

A screenshot or payment reference alone is not proof of payment. Do not verify until the transaction is confirmed in the official account/merchant records.

### Netlify deployment (no GitHub Pages required)

This archive is arranged with `index.html` at the archive root and `netlify/functions/` at the root. Deploy it to the Netlify site using the Git-connected repository or Netlify manual deploy after extracting the ZIP.

1. Extract this ZIP. Upload the **contents** of the extracted `SADEE PRO STORE` folder to the GitHub repository root, so `index.html`, `config.js`, `netlify.toml`, `admin/`, and `netlify/functions/` are directly visible at the repository root.
2. In Netlify, open **Site configuration → Build & deploy → Continuous deployment** and connect the repository. Set the base directory to blank/root, build command to blank, and publish directory to `.`. The included `netlify.toml` also declares these settings.
3. Do not use GitHub Pages for this site. Netlify is the hosting provider; GitHub is only the source-code repository.
4. Add the required Netlify environment variables listed above, then trigger a fresh deploy.
5. After deploy, test `https://YOUR-SITE.netlify.app/.netlify/functions/validate-promo` in a browser. A JSON `Method not allowed` response is expected for GET and confirms the function route is deployed. An HTML 404 means the wrong deploy source or publish configuration is still active.
6. Do not use a plain static drag-and-drop deploy if you need the server-side checkout/admin functions. Use a Netlify deploy that includes the `netlify/functions/` directory.

### 5. Promo codes

Promo codes are validated server-side when an order is submitted. Discounts are applied to the order amount. This is a manual-payment checkout, not an automatic eZ Cash gateway. Verify the final amount received matches the discounted amount before issuing a key.

### 6. Testing checklist

- Test product add/edit/delete with the admin secret.
- Test image upload with a small JPG/PNG/WebP/GIF (maximum about 3 MB).
- Test promo code with valid, expired/invalid and repeated-code cases.
- Submit a test order, confirm it stays pending, then test reject and verify flows.
- Confirm stock decrements only after successful verification; restock products before verifying if stock is zero.
- Confirm Order Status does not reveal a key for pending/rejected orders.
- Configure Resend and test email delivery before using it for real orders.
- Test phone layout and PWA install on the deployed HTTPS domain.

## Security notes

- Product, settings, image upload and order-review mutations are routed through server-side Netlify Functions using `STORE_ADMIN_SECRET` and `SUPABASE_SERVICE_ROLE_KEY`.
- Never put `SUPABASE_SERVICE_ROLE_KEY`, `STORE_ADMIN_SECRET` or Resend secrets in browser code.
- The order lookup currently relies on the order code plus matching email. Add rate limiting/CAPTCHA at the edge before a high-traffic public launch.
- Review submissions are hidden until approved by an admin.
- This project uses manual eZ Cash verification; it does not automatically query eZ Cash transaction records.
- A promo code is applied to the order total; check the amount received before verifying payment.


## Order status + manual license issue update

1. Run `supabase/order-license-duration-and-stock.sql` in the Supabase SQL Editor. This adds `license_duration`, sets active product stock to 999, and installs the stock decrement function.
2. Deploy the complete project to Netlify (publish directory `.`; functions directory `netlify/functions`).
3. In Admin → Orders, check the customer transaction reference against the actual incoming eZ Cash transaction. Enter the exact license key and its validity (for example `30 days`, `6 months`, or `Lifetime`), then use **Verify payment & issue key**. The key is not shown to the customer before this succeeds.
4. Customers open `order-status.html` / **My Orders**, paste their order code, enter the checkout email, and can view/copy/share the issued key and its validity. Pending orders refresh automatically while the page remains open.

Do not share the Netlify `STORE_ADMIN_SECRET` or Supabase service-role key. Stock 999 is a requested availability setting, not proof that 999 separate license keys are on hand; only issue keys you can fulfil.

## ULTIMATE GAMING EDITION update
This package adds an additive database migration at `supabase/ultimate-update.sql`.
Run it once in Supabase SQL Editor before deploying. It adds `license_expires_at`, enforces case-insensitive uniqueness for payment references and license keys, and creates a private license-key change audit table. The migration intentionally stops with an error if historical duplicate references or keys exist; review those records first rather than deleting customer data.

Admin Orders now includes search, status filters, Pending / Verified / Rejected counts, manual key issue, and safe key replacement. Key expiry is calculated by the server for recognizable durations such as `30 days`, `3 months`, `1 year`, or `Lifetime`. Custom duration text that cannot be parsed is stored as a label without an expiry date; use clear day/week/month/year wording for automatic expiry.

New customer information pages: `faq.html`, `support.html`, and `terms.html`. Order lookup remains `order-status.html` and requires both order code and checkout email. Payment is still manually verified against the actual incoming eZ Cash transaction; submitting a reference does not prove payment. Never issue a key before confirming payment.

Deployment: upload the ZIP contents to the existing GitHub repository root and let Netlify redeploy. Keep `SUPABASE_SERVICE_ROLE_KEY` and `STORE_ADMIN_SECRET` only in Netlify environment variables. Do not commit secrets to GitHub. Confirm the deploy URL and test with a small test order before using live customer orders.


## Ultimate enhancements added
- Payment reference uniqueness ignores blank legacy values but prevents reuse of every non-empty reference.
- License keys have case-insensitive duplicate protection and change history.
- Automatic expiry dates for day/week/month/year plans; lifetime has no expiry.
- Order search, status filters and Pending/Verified/Rejected dashboard cards.
- Customer order lookup displays payment reference and whether a receipt was attached; verified customers can copy/share their key.
- Admin can edit or delete announcements and maintenance posts.
- Hero media can be uploaded from a phone or computer (MP4/WebM video or JPG/PNG/WebP image, up to 4 MB). Hero video is displayed in a compact, contained area.
- Optional receipt photo upload at checkout (JPG/PNG/WebP, up to 3 MB), stored in a private bucket.
- Improved contrast for buttons and mobile admin controls.

### Required Supabase Storage setup
Create `hero-media` as a **public** bucket and `order-receipts` as a **private** bucket. Do not create public read policies for `order-receipts`. The Netlify Functions upload both media types using `SUPABASE_SERVICE_ROLE_KEY`.
Run `supabase/ultimate-enhancements.sql` after backing up the database. Existing orders are preserved.

### 20 quality improvements included/planned in this edition
1. Duplicate payment reference protection; 2. duplicate license key protection; 3. automatic expiry calculation; 4. searchable orders; 5. status filters; 6. status dashboard cards; 7. license copy; 8. license share; 9. license key history; 10. responsive admin controls; 11. hero video file upload; 12. hero image upload; 13. compact hero video; 14. receipt image upload; 15. receipt privacy via private bucket; 16. payment reference visibility in My Orders; 17. receipt-upload indicator in My Orders; 18. announcement editing; 19. announcement deletion; 20. higher-contrast buttons and mobile layout polish.


## Cyber App Edition updates
See `APP-20-AND-SITE-50-UPDATES.txt` for the complete 20 app/PWA and 50 website feature list. Admin > Store branding now supports changing the store name and uploading a logo. The homepage hero photo/video remains empty by default.
