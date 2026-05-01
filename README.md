# CafeManager

CafeManager is a SwiftUI inventory app for a small cafe manager who needs a simple way to track stock, update records, and spot issues before they become urgent.

## Project Brief

The app is designed around a practical cafe workflow:

- Add inventory items.
- View all items in one place.
- Edit existing records.
- Delete items that are no longer needed.
- Surface low-stock and out-of-stock risks early.

## Features

- Full CRUD for cafe inventory items.
- Firebase Firestore persistence.
- SwiftUI interface with loading, empty, and error states.
- Smart assistant panel that prioritizes:
  - out-of-stock items,
  - low-stock items below their threshold,
  - grouped reorder opportunities,
  - records with missing or invalid threshold setup.

## Data Model

Each inventory item stores:

- `id`
- `name`
- `quantity`
- `threshold`

The app currently focuses on inventory management because that is the most direct way to satisfy the cafe manager's daily needs with a clean and understandable flow.

## Architecture

The project follows a lightweight MVVM structure:

- `Views/`
  SwiftUI screens for listing, adding, editing, and showing assistant insights.
- `ViewModels/`
  Business logic for assistant recommendations.
- `Services/`
  Firestore integration and persistence logic.
- `models/`
  Shared domain model types.

## Firebase Integration

Firebase is configured through `GoogleService-Info.plist`, and inventory data is persisted in Firestore.

Current Firestore operations:

- create item
- fetch items
- update item
- delete item

## Smart Feature

Instead of using fake sales-per-day predictions, the assistant uses real inventory data to help the manager act faster. It identifies what needs attention first, which items should be reordered together, and where stock thresholds are missing or misconfigured.

This keeps the feature useful without inventing demand numbers the app cannot justify.

## Error Handling

The app includes defensive handling for common failure cases:

- empty item names are rejected,
- invalid numeric input is rejected,
- Firestore fetch/write/delete failures surface an error message,
- loading and empty states are shown in the main inventory screen.

## Running the Project

1. Open `CafeManager.xcodeproj` in Xcode.
2. Make sure the Firebase configuration file is present.
3. Build and run on an iOS simulator or device.

## Current Status Against the Brief

- Full CRUD: implemented
- Firebase Integration: implemented with Firestore
- Clean Architecture: implemented with separate views, view model, model, and service layers
- Error Handling: implemented for empty input, invalid values, empty states, loading states, and network failures
- AI/Smart Feature: implemented as an inventory prioritization assistant based on real stock data

## Future Improvements

- Firebase Authentication for manager login
- Supplier tracking and payable balances
- Order history and purchase records
- Analytics backed by real sales data for stronger forecasting
