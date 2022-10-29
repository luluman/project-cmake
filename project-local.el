;;; project-local.el --- Local variables for projects  -*- lexical-binding: t; -*-

;; Version: 0.1
;; Author: Juan Jose Garcia-Ripoll
;; Maintainer: Juan Jose Garcia-Ripoll <juanjose.garciaripoll@gmail.com>
;; URL: https://github.com/juanjosegarciaripoll/project-cmake
;; Keywords: convenience, languages
;; Package-Requires: ((emacs "26.1") (project "0.3.0"))

;; MIT License

;; Copyright (c) 2022 Juan José García Ripoll

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.


;;; Commentary:

;; This package extents `project` to define project-local variables,
;; much like dir-local variables already do. Those variables are
;; stored into a .project.el file at the root of the project, without
;; the cumbersome syntax of dir-local variables, but rather as a
;; series of `defvar` statements.
;;

(require 'project)
(require 'wid-edit) ;; widget-convert
(require 'cus-edit) ;; custom-variable-type

(defcustom project-local-confirm-save t
  "Ask for confirmation before saving a project's variable file.")

(defvar project-local-cache nil
  "Association between projects and assignments. This is an association
between projects and association lists, indexed by variable names that
take local values. A project's record may also contain values indexed
by keywords (e.g. :filename, :date, etc) which are not saved but are
used during the manipulation of a project.")

(defun project-local-map-records (fn)
  (dolist (pair project-local-cache)
	(let ((project (car pair))
		  (record (cdr pair)))
	  (funcall fn project record))))

(defun project-local-file-name (project)
  "Return the canonical name for a project's local variable file."
  (let ((root (project-root project)))
	(expand-file-name ".project.el" root)))

(defun project-local-new-record (project)
  (list (cons :filename (project-local-file-name project))))

(defun project-local-set-record (project record)
  (let ((previous (assoc project project-local-cache)))
	(if previous
		(rplacd previous record)
	  (push (cons project record) project-local-cache)))
  record)

(defun project-local-remove-record (project)
  (setq project-local-cache (delq (project-local-cached-record project)
								  project-local-cache)))

(defun project-local-record-set (record variable value)
  (let ((field (assq variable record)))
	(if field
		(setcdr field value)
	  (setcdr record (cons (cons variable value) (cdr record)))))
  record)

(defun project-local-record-value (record variable &optional default)
  (let* ((field (assq variable record)))
	(if field
		(cdr field)
	  default)))

(defun project-local-record-map-values (record function)
  (dolist (pair record)
	(let ((variable (car pair))
		  (value (cdr pair)))
	  (funcall function variable value))))

(defun project-local-record-mark-as-changed (record)
  (project-local-record-set record :changed t))

(defun project-local-record (project)
  "Return the record of variables associated to a project. It may be taken
from the cache or read from a project's local variables file. If it does
not exists, it creates a new record that is added to the cache."
  (or (project-local-cached-record project)
	  (project-local-load-record project)))

(defun project-local-cached-record (project)
  "Return the existing record of a project, if it exists, or NIL if it doesn't."
  (assoc project project-local-cache))

(defun project-local-value (project variable)
  "Return the project-local value assigned to VARIABLE or the globally
bound value for that symbol."
  (project-local-record-value (project-local-record project)
							  variable
							  (and (boundp variable)
								   (symbol-value variable))))

(defun project-local-set (project variable value)
  "Assign a project-local VARIABLE a VALUE. It may create a new record in the
project-local cache, that will have to be saved later on."
  (let ((record (project-local-record project)))
	(project-local-record-set record variable value)
	(project-local-record-mark-as-changed record)
	value))

(defun project-local-edit (project variable)
  (let* ((prompt (format "Value of %s: " variable))
		 (widget (widget-convert (custom-variable-type variable)))
		 (value (project-local-value project variable))
		 (new-value-string (read-from-minibuffer prompt (format "%S" value)))
		 (new-value (car (read-from-string new-value-string))))
	(if (widget-apply widget :match new-value)
		(project-local-set (project-current t) variable new-value)
	  (error "The value does not match the expected type for %S"
			 variable))))

(defun project-local-load-record (project)
  "Return a new record for it."
  (project-local-set-record project (project-local-new-record project)))

(defun project-local-clear (&optional project)
  (interactive)
  (project-local-remove-record (or project (project-current t))))

(provide 'project-local)
