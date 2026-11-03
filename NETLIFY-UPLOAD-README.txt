SADEE XDIMA — NETLIFY UPLOAD PACKAGE

This ZIP is arranged with the website files at the ZIP ROOT (not inside a nested sadee_next folder).

STATIC SITE / MANUAL DEPLOY
1. Extract this ZIP.
2. In Netlify, open your site and go to Deploys.
3. Use the manual deploy / deploy manually area and upload the EXTRACTED FOLDER contents (the folder containing index.html, netlify.toml, assets/, admin/, and netlify/).
4. Do not upload the ZIP as a nested folder and do not set publish directory to sadee_next. The publish directory for this root package is ".".
5. After deploy, open the site in a private/incognito tab or clear site data, then reload.

IMPORTANT ABOUT SERVER FUNCTIONS
The netlify/functions folder and netlify.toml are included. Netlify manual drag-and-drop deploys may publish the static site without building/deploying Functions. To activate backend order/payment/admin functions, use a Netlify build deploy (connect the Git repository or use Netlify CLI) with this folder as the project root. Build command can remain blank; publish directory is "."; functions directory is "netlify/functions".

SUPABASE
Do not run SQL blindly on a live database. Back up first and review the migration. Keep SUPABASE_SERVICE_ROLE_KEY and STORE_ADMIN_SECRET only in Netlify environment variables. Never put service-role secrets in config.js or public files.

LOADING SCREEN FIX
The loading screen is included at the site root, uses inline critical overlay styles (so it still displays if styles.css is delayed), preloads the branded image, stays visible for at least 1.8 seconds, and has a 6.5-second safety timeout. The service-worker cache was bumped to v8 and the loading image is included in the shell cache. HTML and service-worker responses are no-cache.

This package has not been deployed to your Netlify account and cannot confirm live Supabase credentials or payment processing. Test orders with a safe test setup before taking real payments.
