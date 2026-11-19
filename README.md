# Setup
1. Copy odoo/salesman_mobile to your Odoo 17 addons, Apps > Update list > install (needs base_geolocalize).
2. Users > a salesman > "Salesman" tab: set Inventory location. Geolocate customers (partner lat/long).
3. Radius: Settings > Technical > System Parameters > salesman_mobile.radius_m (default 50).
4. Flutter: `flutter create . --platforms=android` inside app/ (keeps lib/ & pubspec), then add to
   android/app/src/main/AndroidManifest.xml: <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   Then `flutter pub get && flutter run` / `flutter build apk`.
# Customer app link
POST /salesman/api/request/create {partner_id, product_id, qty, note, source:"customer_app"} -> appears under Sales > Customer Requests and in salesmen's Requests tab.
Before going live, give the customer app its own auth (API key/portal user) instead of a salesman session.
