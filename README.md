# vui-hash-table.el

A hash table UI component for the VUI framework in Emacs.

## Overview

`vui-hash-table.el` provides a table component that displays data from a hash table with interactive sorting and selection capabilities.

## Features

- **Sortable columns** — Click column headers to sort the table
- **Reversible sort** — Click again to reverse sort order (↑/↓ indicators)
- **Row selection** — SPC to toggle selection, RET to execute actions on selected items
- **Configurable formatters** — Custom formatters for column values

## Usage

```elisp
(require 'vui-hash-table)

;; Define a hash table component
(vui-hash-table-defcomponent my-table
  :border t
  :sticky-header t)
```

## Component Props

| Key        | Type | Description                           |
|------------|------|---------------------------------------|
| `:headers` | list | Column definitions (see Header Props) |
| `:table`   | list | List of hash tables to display        |

## Header Props

Each header is a cons cell `(key . props)`:

| Key            | Type     | Description                           |
|----------------|----------|---------------------------------------|
| `:header`      | string   | Column display name                   |
| `:width-ratio` | number   | Proportion of window width (0.0–1.0) |
| `:formatter`   | function | Function to format cell values        |
| `:sort-func`   | function | Custom sort function                  |
| `:sorted`      | boolean  | Column is currently sorted            |
| `:reversed`    | boolean  | Sort is reversed                      |

## Functions

### `vui-hash-table-mount` (name buffer-name actions &rest props)

Mount a hash table component in a buffer and return the instance.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | symbol | Component name (from `vui-hash-table-defcomponent`) |
| `buffer-name` | string | Buffer to mount in (created if doesn't exist) |
| `actions` | function | Called with selected keys list on RET press |
| `props` | plist | Props passed to the VUI component (`:headers`, `:table`) |

### `vui-hash-table-clear-selected` ()

Clear all row selections in the current component.

## Variables

- `vui-hash-table--instance` — Current component instance
- `vui-hash-table--selected` — List of selected row keys
- `vui-hash-table--actions` — Action function called on RET

## Keybindings

| Key | Action |
|-----|--------|
| `SPC` | Toggle row selection |
| `RET` | Run actions on selected rows |
| `click header` | Sort by column |

## License

GNU General Public License v3
