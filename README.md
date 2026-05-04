# CafeManager

CafeManager is a SwiftUI app for running day-to-day cafe operations. It helps a cafe manager take customer orders, manage inventory, monitor stock risk, and keep data synced with Firebase Firestore.

## Overview

The app is built around a practical cafe workflow:

- start from a cafe dashboard,
- move into order taking during service,
- manage and restock inventory,
- use smart assistant insights to catch stock problems early.

## Current Features

### App Navigation

- Sidebar-based navigation.
- Default landing screen is a `Cafe Manager` overview page.
- Main sections:
  - `Take Order`
  - `Inventory`

### Cafe Manager Home

- Quick entry points into `Take Order` and `Inventory`.
- At-a-glance summary for:
  - active orders,
  - low-stock items,
  - total inventory items.

### Take Order Flow

- Create a new order from the `Take Order` page.
- Select a table number for new orders.
- See menu items one by one with:
  - food item name,
  - minus button,
  - quantity in the middle,
  - plus button.
- Complete the order from the bottom action bar.
- Prevent ordering more than available stock.
- Save orders to Firestore.
- Reduce inventory automatically when an order is completed.

### Order Management

- Recent orders are displayed in the `Take Order` page.
- Reopen an existing order using `Order More`.
- `Order More` keeps the same table locked and lets the staff add additional items.
- Additional items merge into the same order record instead of creating a duplicate order.
- Delete an order with confirmation.
- Deleting an order restores its item quantities back into inventory.

### Inventory Management

- Add inventory items.
- View all inventory in one place.
- Edit existing inventory items.
- Delete inventory items.
- Highlight low-stock items when quantity is at or below the threshold.

### Smart Assistant

The inventory page includes a smart assistant that uses both stock data and recent order activity.

It currently provides:

- urgent out-of-stock alerts,
- next restock priority recommendations,
- grouped reorder suggestions,
- invalid threshold warnings,
- low-stock items that are also actively selling,
- slow-moving stock with high quantity and no recent demand.

The assistant also supports an on-device AI inventory briefing using Apple Foundation Models when available. If Apple Intelligence is unavailable, the app falls back gracefully to rule-based insights.

## Data Model

### Inventory Item

Each item stores:

- `id`
- `name`
- `quantity`
- `threshold`

### Order

Each order stores:

- `id`
- `tableNumber`
- `createdAt`
- ordered items with item id, item name, and quantity

## Architecture

The project follows a lightweight MVVM-style separation:

- `Views/`
  SwiftUI screens for dashboard, ordering, inventory, and assistant UI.
- `ViewModels/`
  Assistant logic and smart inventory analysis.
- `Services/`
  Firestore persistence and batch inventory/order updates.
- `models/`
  Shared data types for inventory items, orders, and order selections.

## Firebase Integration

Firebase is configured with `GoogleService-Info.plist`.

Firestore is used for:

- storing inventory items,
- storing customer orders,
- updating stock after order completion,
- restoring stock when orders are deleted.

Current Firestore operations include:

- create item
- fetch items
- update item
- delete item
- create or update order
- fetch orders
- delete order

## Error Handling

The app includes defensive behavior across the main flows:

- empty names are rejected,
- invalid numeric input is rejected,
- empty orders cannot be completed,
- ordering is blocked when stock is insufficient,
- order deletion confirms before removing data,
- Firestore failures surface error messages,
- loading and empty states are shown in key screens.

## Platform Notes

- Built with SwiftUI.
- Uses Firebase Firestore for persistence.
- Supports Apple Foundation Models for the AI inventory briefing when the device and OS support it.

## Running the Project

1. Open `CafeManager.xcodeproj` in Xcode.
2. Ensure `GoogleService-Info.plist` is present and valid.
3. Build and run on a simulator or device.

## Status Against the Brief

- Full CRUD: implemented for inventory items
- Firebase Integration: implemented with Firestore
- AI Feature: implemented through smart inventory insights and optional on-device AI briefing
- Clean Architecture: implemented with separated views, service layer, model layer, and assistant view model
- Error Handling: implemented across inventory, ordering, loading, and Firestore failure states

## Future Improvements

- Firebase Authentication for staff login
- Supplier management and payable tracking
- Order status lifecycle such as open, served, paid, and closed
- Real sales analytics and stronger demand forecasting
- Dedicated menu model separate from raw inventory items
