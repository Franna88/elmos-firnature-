# SAMA App Routing System Documentation

## Overview

The SAMA app uses a sophisticated routing system built with **GoRouter** that provides seamless navigation, URL persistence, and browser reload support. This system allows users to navigate between different sections of the app while maintaining proper URL states and enabling direct access to specific pages via URLs.

## Architecture Components

### 1. URL Strategy Configuration

The app uses `usePathUrlStrategy()` to create clean, SEO-friendly URLs without hash fragments:

```dart
// lib/main.dart
if (kIsWeb) {
  usePathUrlStrategy();
}
```

This removes the `#` from URLs, making them look like regular web URLs:
- ✅ `/products` (clean URL)
- ❌ `/#/products` (hash-based URL)

### 2. Router Configuration Structure

The app uses a hierarchical route structure with GoRouter:

```dart
// lib/routes/RouterConfig.dart
GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: RouterNames.home,
      builder: (BuildContext context, GoRouterState state) => MyHome(),
      routes: [
        // Nested routes for different pages
        GoRoute(path: 'products', ...),
        GoRoute(path: 'events', ...),
        // etc.
      ]
    )
  ]
)
```

### 3. Route Names Constants

Route names are centralized in `RouterNames.dart` for consistency:

```dart
// lib/routes/RouterNames.dart
class RouterNames {
  static const String home = 'home';
  static const String login = 'login';
  static const String products = 'products';
  static const String events = 'events';
  static const String cpd = 'cpd';
  // ... more route names
}
```

## Navigation Flow

### Internal Navigation (Menu Clicks)

When a user clicks a menu item:

1. **Menu Click Handler**: `_handleItemClick()` is triggered with a `pageIndex`
2. **URL Update**: The app calls `GoRouter.of(context).go('/some-path')`
3. **Route Matching**: GoRouter matches the URL to the route configuration
4. **Page Rendering**: The appropriate `PostLoginLandingPage` is rendered with the correct `pageIndex`

```dart
// lib/homePage/dashboard/menu/PostLoginLeft.dart
void _handleItemClick(int index, int pageIndex) async {
  setState(() {
    activeIndex = index;
  });

  if (pageIndex != -1) {
    switch (pageIndex) {
      case 0: // Dashboard
        GoRouter.of(context).go('/');
        break;
      case 1: // Centre of Excellence
        GoRouter.of(context).go('/centre-of-excellence');
        break;
      case 2: // Member Benefits
        GoRouter.of(context).go('/member-benefits');
        break;
      // ... more mappings
    }
  }
}
```

### Browser Reload Handling

When the browser is reloaded:

1. **URL Loading**: Browser loads the current URL (e.g., `/products`)
2. **Route Matching**: GoRouter matches the URL to the route configuration
3. **Page Creation**: Route builder creates `PostLoginLandingPage` with correct parameters
4. **State Initialization**: `PostLoginLandingPage.initState()` sets `currentPageIndex`
5. **Content Rendering**: The correct page content is displayed

```dart
// lib/homePage/PostLoginLandingPage.dart
@override
void initState() {
  // Set initial page index based on route parameters
  currentPageIndex = widget.pageIndex ?? 0;
  
  // Handle special cases like product redirects
  if (widget.productId != null && widget.productRedirect == true) {
    getProductData(widget.productId!);
  }
  
  super.initState();
}
```

## Page Index to URL Mapping

The app maintains a bidirectional mapping between internal page indices and URL paths:

### Page Index → URL
```dart
switch (pageIndex) {
  case 0:  GoRouter.of(context).go('/');                    // Dashboard
  case 1:  GoRouter.of(context).go('/centre-of-excellence'); // Centre of Excellence
  case 2:  GoRouter.of(context).go('/member-benefits');     // Member Benefits
  case 9:  GoRouter.of(context).go('/media');               // Media & Webinars
  case 10: GoRouter.of(context).go('/events');              // Events
  case 14: GoRouter.of(context).go('/products');            // E-Store
  case 16: GoRouter.of(context).go('/communities');         // Communities
  case 19: GoRouter.of(context).go('/cpd');                 // Professional Development
  case 39: GoRouter.of(context).go('/free-coding-product'); // Spasticity Coding Browser
}
```

### URL → Page Index
```dart
void _setActiveIndexFromRoute() {
  final currentPath = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
  
  switch (currentPath) {
    case '/':                    setState(() => activeIndex = 0);  break;
    case '/centre-of-excellence': setState(() => activeIndex = 1);  break;
    case '/member-benefits':      setState(() => activeIndex = 2);  break;
    case '/media':               setState(() => activeIndex = 9);  break;
    case '/events':              setState(() => activeIndex = 10); break;
    case '/products':            setState(() => activeIndex = 14); break;
    case '/communities':         setState(() => activeIndex = 16); break;
    case '/cpd':                 setState(() => activeIndex = 19); break;
    case '/free-coding-product': setState(() => activeIndex = 39); break;
  }
}
```

## Dynamic Content Handling

### Product Pages
For dynamic product pages, the app uses URL parameters:

```dart
// Route definition
GoRoute(
  path: 'product-/:id',
  name: RouterNames.singleProduct,
  builder: (BuildContext context, GoRouterState state) {
    var id = state.pathParameters['id'];
    return Material(
      child: PostLoginLandingPage(
        pageIndex: 31,
        productId: id,
        productRedirect: true,
      ),
    );
  },
),

// Direct product route (alternative format)
GoRoute(
  path: '/products/product-id=:id',
  builder: (BuildContext context, GoRouterState state) {
    var id = state.pathParameters['id'];
    return Material(
      child: PostLoginLandingPage(
        pageIndex: 14,
        productId: id,
        productRedirect: true,
      ),
    );
  },
),
```

### Event Pages
Similar pattern for event pages:

```dart
GoRoute(
  path: 'event-id=:id',
  name: RouterNames.singleEvent,
  builder: (BuildContext context, GoRouterState state) {
    var id = state.pathParameters['id'];
    return Material(
      child: PostLoginLandingPage(
        userId: "",
        activeIndex: 3,
        eventId: id,
        eventRedirect: true,
      ),
    );
  },
),
```

## Page Content Rendering

The `PostLoginLandingPage` uses a `currentPageIndex` to determine which content to display:

```dart
// lib/homePage/PostLoginLandingPage.dart
var pages = [
  // 0 - Dashboard
  DashboardMain(userNotification: userNotification, userType: userType),
  // 1 - Centre of Excellence
  CenterOfExcellence(getArticleId: getArticleId, changePage: changePage),
  // 2 - Member Benefits
  MemberBenifits(),
  // 3 - Profile
  Profile(userType: userType),
  // ... more pages (40+ total)
];

// Render the current page
pages[currentPageIndex]
```

## Key Features

### ✅ URL Persistence
- URLs are updated as users navigate through the app
- Browser back/forward buttons work correctly
- URLs are bookmarkable and shareable

### ✅ Browser Reload Support
- App maintains state across browser reloads
- No redirects to home page on reload
- Direct access to any page via URL

### ✅ SEO Friendly
- Clean URLs without hash fragments
- Proper route structure for search engines
- Descriptive URL paths

### ✅ Dynamic Content
- Support for parameterized routes (products, events)
- Flexible routing for different content types
- Fallback handling for missing content

## Route Structure

```
/                           # Home/Dashboard
├── login                   # Login page
├── register                # Registration page
├── cpd                     # Professional Development
├── cpd-register           # CPD Registration
├── media                   # Media & Webinars
├── events                  # Events listing
│   └── event-id=:id       # Specific event
├── products                # Products listing
│   └── product-/:id       # Specific product
├── coding-products-test    # Coding products test
├── free-coding-product     # Free coding product
├── spasticity-coding-browser # Spasticity coding browser
├── centre-of-excellence    # Centre of Excellence
├── communities             # Communities
├── member-benefits         # Member Benefits
└── branch-voting           # Branch Voting

/products/product-id=:id   # Alternative product route
/member-verification       # Member verification page
```

## Best Practices

1. **Always use RouterNames constants** for route names to maintain consistency
2. **Handle both pageIndex and URL parameters** for dynamic content
3. **Provide fallback behavior** for missing content or errors
4. **Test browser reload scenarios** to ensure proper state restoration
5. **Use descriptive URL paths** that reflect the content structure

## Troubleshooting

### Common Issues

1. **Page not loading on reload**: Check if the route is properly defined in `RouterConfig.dart`
2. **Wrong page index**: Verify the mapping between URL and `pageIndex` in `PostLoginLeft.dart`
3. **Dynamic content not loading**: Ensure `productRedirect` or `eventRedirect` flags are set correctly
4. **URL not updating**: Check if `GoRouter.of(context).go()` is being called with the correct path

### Debug Tips

- Use browser developer tools to inspect URL changes
- Check console logs for route matching information
- Verify `currentPageIndex` values in `PostLoginLandingPage`
- Test direct URL access for each route

This routing system provides a robust foundation for the SAMA app's navigation, ensuring a smooth user experience across all platforms and scenarios. 