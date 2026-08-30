# Manual Sync Verification Plan

Follow these 4 scenarios to verify that the **Offline-First Architecture** and **Sync Feedback UI** are working as designed.

## Scenario 1: The "Airplane Mode" Change
**Goal**: Verify local persistence and the "Silent Launch" logic.
1.  Turn on **Airplane Mode**.
2.  Add a new **Meal** in the Calorie tracker and an **Affirmation** in the Library.
3.  **Verify**: Both items appear immediately in the UI.
4.  Kill the app and restart it (still offline).
5.  **Verify**:
    - The items are still there.
    - **No sync popups** appear on launch.

## Scenario 2: The "Handshake" (Back Online)
**Goal**: Verify the "Internet Restored" sequence and progress bar.
1.  Ensure you have offline data from Scenario 1.
2.  Turn off Airplane Mode.
3.  **Verify**:
    - A sleek **"INTERNET CONNECTION RESTORED"** card slides up above the bottom nav.
    - It transitions to **"SYNCHRONIZING OFFLINE DATA..."**.
    - The counter shows **0/2**, then **1/2**, then **2/2** as items sync.
    - A **Green Tick** appear with "SYNCHRONIZATION COMPLETE".
4.  Check the **Supabase Dashboard**.
5.  **Verify**: The new Meal and Affirmation are now in the cloud tables.

## Scenario 3: The "Ghost" Deletion
**Goal**: Verify that offline deletes are correctly queued and processed.
1.  Go back to **Airplane Mode**.
2.  Delete a **Supplement** or a **Workout**.
3.  Reconnect to Wi-Fi.
4.  **Verify**:
    - The Sync UI appears and shows progress.
    - The item is removed from the **Supabase Dashboard** automatically.

## Scenario 4: The Multi-Device Conflict
**Goal**: Verify that newer cloud data doesn't overwrite your local offline work.
1.  Go offline on Device A.
2.  Change your **Display Name** to "Mentzer 1" in Profile.
3.  On Device B (Online), change your name to "Mentzer 2".
4.  Wait 10 seconds, then go online on Device A.
5.  **Verify**:
    - Device A pushes "Mentzer 1" to the cloud.
    - Because Device A's change has a newer timestamp, "Mentzer 1" remains the winner in Supabase.
