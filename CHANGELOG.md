# Change Log
All notable changes to this project will be documented in this file.
"Unreleased" changes are implemented but haven't been uploaded yet.

## Unreleased
- Removed auto-titles.
- Update Electron framework from 1.4.14 to 1.7.4-beta


## [0.1.3] - 2017-01-16
- User info from download added to Intercom (name & contact email).
- Can now save document while editing card.
- Fixed Markdown export when using autoheadings.
- Fixed textareas not growing when text hits bottom, when first created.
- Second attempt to fix crash when opening external links.
- Upgrade Electron framework from 1.4.3 to 1.4.14


## [0.1.2] - 2017-01-10
- Fixed crash when clicking on http links within app.
- Send anonymous user data to Intercom (number of saves, version number, etc).


## [0.1.1] - 2017-01-05
- Installed Intercom instead, for smoother "Contact Support" experience.


## [0.1.0] - 2017-01-05
- Added link for direct support chat with me.


## [0.0.15] - 2017-01-03
- Added occasional request for payment (Pay What You Want).


## [0.0.14] - 2016-12-19
- Readded Undo/Redo functionality.


## [0.0.13] - 2016-12-19
- Core rewrite for performance improvements.
- **Forced to remove Undo/Redo temporarily**.


## [0.0.12] - 2016-12-06
- Greatly improved performance on large trees.
- Fixed bug: As of 0.0.10, wasn't able to "File > New". Now works.
- Temporarily (?) removed "fade background" effect while editing, for performance.


## [0.0.11] - 2016-12-05
- Temporarily removed buggy "save backup while typing".
- Slight performance improvement via lazier rendering. Still laggy on large trees.


## [0.0.10] - 2016-11-30
- Recovery file: on any card insertion/deletion/moves, and every ~10 characters.
- Warn on loading a file if a recovery file is also found.


## [0.0.9] - 2016-11-24
- Menu fixed on macOS (wasn't showing "File|Gingko", "Edit", "View", or "Debug" menus).
- Fixed: Onload "File not found" error for macOS.
- InsertAbove/Below commands when on Root card no longer creates children.
- Cards now have max-height on edit mode, then switch to scroll. 
Prevents scrolling bugs with long cards.
- Ctrl/Cmd arrows in edit mode no longer create cards
(shortcut conflicted with text navigation).
- Pressing Tab in edit mode inserts two spaces (previously: lost focus).
- Code blocks (triple backtick) now preserve whitespace.


## [0.0.8] - 2016-11-18
- Fixed import bug: importing from web app "Copy" operation worked,
but when importing from web app "Export", only first card was imported.
- Added Ctrl+Arrows to create cards, in addition to Ctrl+JKL.


## [0.0.7] - 2016-11-17
- Min-width for columns, horizontal scrolling.


## [0.0.6] - 2016-11-17
- Bug fix: when deep into tree, navigating up or down beyond group boundaries,
didn't work, now does.
- Bug fix: images now scale down to fit in cards.


## [0.0.5] - 2016-11-15
- You can now import trees from GingkoApp.com's JSON format.


## [0.0.4] - 2016-11-15
- To prevent losing unsaved card changes, pressing 'Esc' to cancel changes
now asks for confirmation.


## [0.0.3] - 2016-11-11
- Added automatic titles based on first line of edit area.
First column has h1 headings, second column has h2, etc.
Unless overridden with Markdown "## Headings".
- Fixed bug where clicking "Insert Above|Below|Child" buttons while editing
would blank current card.
- Minor visual changes to card, especially in edit mode.
