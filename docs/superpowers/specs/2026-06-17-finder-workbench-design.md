# Finder Workbench Design

## Summary

Finder Workbench is a lightweight macOS app for keeping frequently used folders visible in one stable workspace. It does not embed Finder windows. Instead, it provides Finder-like folder cards that show file lists, support safe drag-and-drop file transfer, and can open the real folder in Finder when needed.

The product goal is to avoid losing Finder windows, repeatedly reopening common folders, and accidentally closing important workspace views. The app should feel like a quiet file workbench: minimal controls, persistent layout, and most of the screen dedicated to folder cards.

## Goals

- Keep common folders available in one persistent app window.
- Let users dynamically add and close folder cards.
- Support locked cards that cannot be closed, moved, or resized until unlocked.
- Show folder contents in lightweight list-detail views.
- Allow safe copying or moving of files and subfolders between cards.
- Keep the UI minimal, with global controls small and folder cards prominent.
- Stay lightweight: no whole-disk indexing, no heavy background scanning, no content analysis.

## Non-Goals

- Recreating all Finder features.
- Embedding real Finder windows inside the app.
- Full-disk search or Spotlight replacement.
- Multi-window workspace management.
- Automatic file organization rules.
- Cloud sync.
- Finder tags, smart folders, or full Finder service menu parity in the first version.
- Thumbnail-wall or media-library views in the first version.

## Core UX

The app opens to a single workspace window. The top toolbar is intentionally small and contains only global controls:

- Add folder.
- Current transfer mode: Copy.
- Move once.
- Search within open cards.
- Current folder card count.

Folder-level actions live on each card, in the upper-right corner. These actions appear when the card is selected or hovered:

- Lock or unlock.
- Open in Finder.
- Close card.

The main area is a freeform or grid-assisted workspace of folder cards. The app is optimized for the common case of about five or six open folders, but it must not enforce this as a hard limit. Users can add more folders when needed. When there are more cards than fit comfortably, the workspace should remain usable through scrolling and predictable layout behavior rather than refusing additional cards.

## Folder Cards

Each folder card represents a user-authorized folder. A card is a UI container, not a file object.

Cards support:

- List-detail display of folder contents.
- Dragging to move the card within the workspace.
- Dragging edges or corners to resize the card.
- Larger cards showing more rows and columns.
- Smaller cards showing fewer rows and a compact state.
- Sorting by list columns.
- Opening the represented folder in Finder.
- Closing the card from the workspace.

The default content view is list detail, not thumbnail grid. Initial columns:

- Name.
- Date Modified.
- Size.
- Kind.

Thumbnail previews are deferred. A later version may add optional previews, but the first version should prioritize fast lists, accurate selection, sorting, and drag-and-drop.

## Locking

Lock is a strong layout lock.

When a card is locked:

- It remains visible across app relaunches.
- It cannot be closed.
- It cannot be moved.
- It cannot be resized.
- The close action is hidden or disabled.
- The unlock action remains available.
- File operations inside the card remain allowed.

Locking protects the workspace layout. It does not make files read-only and does not prevent users from copying, moving, selecting, or opening files inside the card.

If a locked card points to a folder that becomes unavailable, the card should remain in the workspace and show an unavailable state. The app must not automatically remove it.

## Closing Cards

The app must avoid dangerous wording such as "delete folder" for card removal. The action should be named "Close Card" or "Remove from Workspace."

Closing a card:

- Removes only the UI card from the workspace.
- Does not delete the real folder.
- Does not delete any files or subfolders.
- Stops watching that folder.
- Releases list data associated with that card.

Locked cards cannot be closed until unlocked.

## File Transfer

Cards themselves cannot be dragged into other cards. Only files and subfolders inside a card can be dragged.

The default transfer mode is Copy. The top toolbar exposes this state clearly.

The user can choose Move once. In this mode:

- The next file or subfolder drag performs a move.
- After that operation completes or fails, the app automatically returns to Copy.
- Move once is not persisted across app launches.

During drag-and-drop, target cards should indicate the current operation, such as "Copy to Client A" or "Move to Client A."

If the target already contains an item with the same name, the app shows a conflict prompt with:

- Keep both.
- Replace.
- Skip.

The first version should not silently overwrite files.

## Adding Folders

The app supports two ways to add folder cards:

- The Add folder button opens a system folder picker.
- Dragging a folder from Finder into the workspace adds it as a card.

Adding a folder must request user-granted access through macOS file permission mechanisms. The app stores a security-scoped bookmark so the folder can be restored on relaunch.

## Finder Integration

The app uses a hybrid strategy:

- Common folder-card workflows happen inside Finder Workbench.
- Advanced or uncommon workflows can be handed off to Finder.

Each card provides Open in Finder. This opens the real folder in Finder without changing the card state.

The app should not rely on controlling Finder windows with AppleScript or Accessibility for core behavior. Those approaches are more fragile and do not match the goal of a stable persistent workspace.

## Technical Architecture

Use a SwiftUI + AppKit hybrid macOS app.

SwiftUI responsibilities:

- Main window.
- Minimal global toolbar.
- Workspace layout.
- Folder card chrome.
- Lock state visuals.
- Transfer mode state.
- Persistence binding.

AppKit responsibilities:

- File list views through NSTableView or a similar mature AppKit table component.
- Multi-selection.
- Drag-and-drop.
- Column resizing and sorting.
- Context menus when needed.
- Quick Look integration if added.

Persistence:

- Store workspace state locally.
- Store security-scoped bookmarks for folders.
- Store card position, size, lock state, display name, sort column, and sort direction.
- Do not store file contents.

Potential persistence options:

- UserDefaults or a small JSON file for MVP simplicity.
- SwiftData later if workspace state becomes relational or needs migration support.

## Permissions

The app should be sandbox-compatible.

Folder access flow:

1. User chooses or drags a folder.
2. App requests access through the system.
3. App stores a security-scoped bookmark.
4. On launch, app resolves bookmarks and restores accessible cards.

If a bookmark is stale or access fails:

- Keep the card in place.
- Show a lightweight unavailable state.
- Offer Relocate and Remove from Workspace.
- Do not remove locked cards automatically.

## Performance Requirements

Finder Workbench must be lightweight.

The app must not:

- Scan the whole disk.
- Run heavy background indexing.
- Analyze file contents.
- Generate large preview caches by default.
- Watch folders that are not open as cards.
- Keep watchers alive after a card is closed.

The app should:

- Read only folders represented by open cards.
- Render file lists lazily or with virtualization.
- Refresh visible cards on demand.
- Throttle file-system change notifications.
- Pause or reduce refresh work for cards that are offscreen.
- Release watchers and list data when cards close.
- Keep idle CPU close to zero.

The app is optimized for roughly five or six active cards, while allowing more when needed. If many cards are open, the app should degrade gracefully through scrolling, compact rendering, and reduced offscreen refresh.

## Error Handling

Folder unavailable:

- Show an unavailable state inside the existing card.
- Offer Relocate.
- Offer Remove from Workspace.
- Keep layout and lock state.

File operation failure:

- Show a human-readable error.
- Avoid destructive partial states when possible.
- Return transfer mode to Copy after Move once attempts.

Permission failure:

- Explain that the app needs access to the folder.
- Offer to reselect the folder.

Same-name conflict:

- Prompt before replacing.
- Provide Keep both, Replace, and Skip.

## MVP Scope

MVP includes:

- One workspace window.
- Minimal top toolbar.
- Add folder by picker.
- Add folder by dragging from Finder.
- Dynamic folder cards.
- List-detail file display.
- Card move and resize.
- Strong lock and unlock.
- Close card without deleting real folders.
- Open in Finder.
- Copy mode.
- Move once mode.
- Drag files and subfolders between cards.
- Same-name conflict prompt.
- Workspace persistence across relaunch.
- Security-scoped bookmarks.
- Lightweight file watching for open cards.

MVP excludes:

- Full Finder feature parity.
- Full-disk search.
- Multi-window workspaces.
- Media preview grid.
- Automatic organization rules.
- Cloud sync.
- Heavy indexing.
- Complex theming.

## Testing Strategy

Unit tests:

- Workspace persistence.
- Card lock state rules.
- Transfer mode state machine.
- Same-name conflict decision handling.
- Bookmark restoration model where testable.

Integration tests:

- Adding and closing cards.
- Closing a card does not delete the underlying folder.
- Locked cards cannot be moved, resized, or closed.
- Default drag operation is copy.
- Move once applies to one operation and then returns to copy.
- Closed cards release watchers.
- Unavailable folders show a recoverable error state.

Manual QA:

- Relaunch restores layout.
- Dragging folders from Finder adds cards.
- Open in Finder opens the correct folder.
- Large directories remain responsive.
- Idle CPU remains low with several cards open.

## Open Decisions

- Whether the workspace layout should be fully freeform, snapped to a grid, or a hybrid.
- Whether search should initially search only visible/open cards or only the selected card.
- Whether card actions appear on hover, selection, or both.
- Whether file operations should use a custom progress HUD in MVP or system progress feedback.
