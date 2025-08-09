# 📌 Kanban Board with Offline Mode and Conflict Resolution

A Flutter-based **Kanban-style task management app** that works both online and offline.  
Users can organize tasks across three columns and sync changes with **Firebase Firestore** when back online.

## 🚀 Features
- **Three-column Kanban board**:
  - 📝 To Do
  - 🚧 In Progress
  - ✅ Done
- **Task Management**:
  - Create, edit, delete tasks
  - Drag & drop between columns
- **Offline Mode**:
  - Local caching of tasks
  - Automatic sync when reconnected
- **Conflict Resolution**:
  - Same field → last-write-wins
  - Different fields → merge changes and notify user
- **File Attachments**:
  - Upload images or PDFs to Firebase Storage *(⚠ Currently disabled due to payment requirements)*

---

## 🛠 Tech Stack
- **Flutter** (UI & logic)
- **Firebase Firestore** (data storage)
- **Firebase Storage** (file uploads)
- **connectivity_plus** (network status detection)
- **Provider / Riverpod** (state management)

---
