;;; vui-hash-table.el --- A hash table UI component for VUI  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Qiqi Jin

;; Author: Qiqi Jin  <ginqi7@gmail.com>
;; Version: 0.01
;; Description: A hash table UI component with sortable columns and row selection
;; Homepage: https://github.com/ginqi7/vui-hash-table
;; Keywords: tools
;; Package-Requires: ((emacs "29.1") (vui "0.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; vui-hash-table.el provides a hash table UI component for the VUI framework.
;;
;; Features:
;;   - Sortable columns (click header to sort, click again to reverse)
;;   - Row selection via SPC, action execution via RET
;;   - Configurable column formatters and width ratios
;;
;; Usage:
;;   (require 'vui-hash-table)
;;   (vui-hash-table-defcomponent my-table :border t :sticky-header t)
;;
;;   (vui-component
;;      'my-table
;;    :headers headers
;;    :table hash-table)

;;; Code:

(require 'vui)

(defvar-local vui-hash-table--instance nil
  "Current VUI hash-table component instance.
Set automatically when rendering the component.")

(defvar-local vui-hash-table--selected nil
  "List of currently selected row keys.
Each element is a string key from the hash table row.")

(defvar-local vui-hash-table--actions nil
  "Function called when RET is pressed on a selected item.
Should be a function that takes no arguments.")

(defun vui-hash-table-format-row (hash header)
  "Format HASH value for a single HEADER column.
Applies :formatter if defined, otherwise formats value as string."
  (let* ((key (car header))
         (value (gethash key hash))
         (props (cdr header))
         (formatter (plist-get props :formatter)))
    (if formatter
        (funcall formatter value)
      (format "%s" value))))

(defun vui-hash-table-to-row (headers hash)
  "Convert HASH row into a list of formatted cell values using HEADERS.
Applies each header's formatter to the corresponding hash value."
  (mapcar (apply-partially #'vui-hash-table-format-row hash) headers))

(defun vui-hash-table-sort-by (sorted-key sort-func reversed table)
  "Sort TABLE by the hash value of SORTED-KEY using SORT-FUNC or string comparison.
When REVERSED is non-nil, reverse the sort order."
  (sort table
        :key (lambda (row) (gethash sorted-key row))
        :lessp (or sort-func (lambda (a b) (string< (format "%s" a) (format "%s" b))))
        :reverse reversed))

(defun vui-hash-table-update-sort-header (headers header)
  "Update HEADERS to mark the sorted HEADER column.
Sets :sorted property to t for HEADER and toggles its :reversed
property."
  (mapcar
   (lambda (one)
     (if (equal one header)
         (cons (car one)
           (plist-put
            (plist-put (cdr one) :sorted (equal one header))
            :reversed (if (plist-get (cdr one) :reversed) nil t)))
       (cons (car one)
           (plist-put
            (plist-put (cdr one) :sorted nil)
            :reversed nil))))
   headers))

(defun vui-hash-table-sort (button header)
  "Sort the table by HEADER column when button is clicked.
BUTTON is the clicked button.  Updates instance props and repositions
point."
  (let* ((instance vui-hash-table--instance)
         (props (vui-instance-props instance))
         (headers (plist-get props :headers))
         (point (button-start button))
         (props (plist-put props :headers (vui-hash-table-update-sort-header headers header))))
    (vui-update-props instance props)
    (goto-char point)))

(defun vui-hash-table-format-column (header)
  "Format HEADER into a clickable column button with sort indicator.
Returns a buttonized string showing the header name."
  (let* ((props (cdr header))
         (name (plist-get props :header)))
    (concat (buttonize name (lambda (button) (vui-hash-table-sort button header)))
            (if (plist-get props :sorted)
                (if (plist-get props :reversed) " ↓" " ↑")
              ""))))

(defun vui-hash-table-to-column (header)
  "Convert HEADER into a column definition with computed width.
Calculates column width from :width-ratio and window width."
  (let* ((props (cl-copy-list (cdr header)))
         (width-ratio (or (plist-get props :width-ratio) 0))
         (width (floor (* (window-width) width-ratio))))
    (plist-put
     (if (> width 0)
         (plist-put props :width width)
       props)
     :header
     (vui-hash-table-format-column header))))

(defun vui-hash-table-to-columns (headers)
  "Convert all HEADERS into column definitions.
Returns a list of column specs with computed widths."
  (mapcar #'vui-hash-table-to-column headers))

(defun vui-hash-table-to-rows (headers table)
  "Convert TABLE rows using HEADERS, applying sort if a column is marked :sorted.
Returns list of formatted row values."
  (let ((sort-header (cl-find-if (lambda (header) (plist-get (cdr header) :sorted)) headers)))
    (mapcar (apply-partially #'vui-hash-table-to-row headers)
            (if sort-header
                (vui-hash-table-sort-by (car sort-header)
                                        (plist-get (cdr sort-header) :sort-func)
                                        (plist-get (cdr sort-header) :reversed) table)
              table))))

(defun vui-hash-table--select ()
  "Toggle selection state for the checkbox at point.
Adds/removes the key at point from `vui-hash-table--selected`."
  (interactive)
  (let* ((data (button-at (point)))
         (begin (button-start data))
         (end (button-end data))
         (key (buffer-substring-no-properties begin end))
         (selected-p (member key vui-hash-table--selected))
         (buffer-read-only nil)
         (inhibit-read-only t))
    (if selected-p
        (progn
          (message "Unselect %s" key)
          (setq vui-hash-table--selected (remove key vui-hash-table--selected)))
      (message "Select %s" key)
      (push key vui-hash-table--selected))
    (put-text-property begin end 'display (if selected-p "☐" "☑"))))

(defun vui-hash-table-format-select (key)
  "Return a checkbox button for KEY, toggled if already selected."
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET")
                (lambda () (interactive)
                  (unless (member key vui-hash-table--selected)
                    (vui-hash-table--select))
                  (when vui-hash-table--actions
                    (funcall vui-hash-table--actions))))

    (define-key map (kbd "SPC") #'vui-hash-table--select)
    (propertize (buttonize (format "%s" key) nil)
                'display (if (member key vui-hash-table--selected) "☑" "☐")
                'keymap map)))

(cl-defun vui-hash-table-defcomponent (&key name border sticky-header)
  "Define a hash table component named NAME.
Optional BORDER and STICKY-HEADER enable table borders and sticky
headers.  Creates a VUI table component that displays hash table data
with sortable columns."
  (eval `(vui-defcomponent ,name (headers table)
           :render
           (vui-vstack
            (vui-muted "Click the HEADER to sort the table by column.")
            (vui-muted "SPC in the checkbox to select an item.")
            (vui-muted "RET in the checkbox to run actions in selected items.")
            (vui-newline)
            (vui-table
             :columns (vui-hash-table-to-columns headers)
             :rows (vui-hash-table-to-rows headers table)
             :border ,border
             :sticky-header ,sticky-header)))))

(provide 'vui-hash-table)
;;; vui-hash-table.el ends here
