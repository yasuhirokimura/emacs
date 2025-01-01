;;; smart-ime.el - smart Input Method -*- lexical-binding: t -*-
;;
;; Copyright (C) 2011 HIROSHI OOTA

;; Author: HIROSHI OOTA
;; Keywords: convenience

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; smart-im frees you from the frustration about IM.
;; It disables an IM automatically according to a situation.

;;; Install:
;; Put this file into load-path'ed directory, and byte compile it if
;; desired.  And put the following expression into your ~/.emacs.
;;
;;     (require 'smart-ime)

;; Todo:

;;; Code:

;; variable
(defvar sime-saved-input-method nil)
(make-variable-buffer-local 'sime-saved-input-method)
(set-default 'sime-saved-input-method nil)

(defun sime-activate-input-method ()
  (setq sime-saved-input-method (list current-input-method))
  (deactivate-input-method))
(defun sime-inactivate-input-method ()
  (when sime-saved-input-method
    (activate-input-method (car sime-saved-input-method))
    (setq sime-saved-input-method nil)))

;;
;; minibuffer
(add-hook 'minibuffer-setup-hook 'sime-activate-input-method)
(add-hook 'minibuffer-exit-hook 'sime-inactivate-input-method)
;;
;; incremental search
(add-hook 'isearch-mode-hook 'sime-activate-input-method)
(add-hook 'isearch-mode-end-hook 'sime-inactivate-input-method)

;;
;; query-replace, query-replace-regexp, query-replace-regexp-eval ...
(advice-add 'perform-replace :around
            (lambda (orig-fun &rest args)
              (let ((im current-input-method)
		    retval)
                (if (or (not im)
	                (not (nth 2 args)))
	            (apply orig-fun args)
                  (deactivate-input-method)
                  (setq retval (apply orig-fun args))
                  (activate-input-method im)
		  retval))))

;;
;; read-passwd
(defvar sime-ad-toggle-ime-mapped-key-list)
(advice-add 'read-passwd :around
            (lambda (orig-fun &rest args)
              (let ((im current-input-method)
		    retval)
                (setq sime-ad-toggle-ime-mapped-key-list nil)
                (dolist (k (where-is-internal
                            'toggle-input-method overriding-local-map nil nil
                            (command-remapping 'toggle-input-method)))
                  (when (integerp (aref k 0))
	            (setq sime-ad-toggle-ime-mapped-key-list
	                  (cons (aref k 0) sime-ad-toggle-ime-mapped-key-list))))

		(advice-add 'read-key :around #'sime-ad-read-key)
                (deactivate-input-method)
                (setq retval (apply orig-fun args))
                (activate-input-method im)
		(advice-remove 'read-key #'sime-ad-read-key)
		retval)))

(defun sime-ad-read-key (orig-fun &rest args)
  (let ((flag t)
	(msg (current-message))
	retval)
    (while flag
      (setq retval (apply orig-fun args))
      (if (not (memq retval
                     sime-ad-toggle-ime-mapped-key-list))
	  (setq flag nil)
	(toggle-input-method)
	(message msg)))
    retval))

;;
;; universal-argument
(advice-add 'universal-argument :before
            (lambda ()
              (setq sime-saved-input-method
                    (or sime-saved-input-method
                        (list current-input-method)))
              (deactivate-input-method)))

(defun universal-argument--mode ()
  (setq sime-saved-input-method
	(or sime-saved-input-method
	    (list current-input-method)))
  (deactivate-input-method)
  (prefix-command-update)
  (set-transient-map universal-argument-map #'sime-inactivate-input-method))

;; a keyboard which has no KANJI-KEY
;; entering/leaving KANJI-mode key-sequence is <kanji><M-kanji>
;; then we should pass prefix-arg to next command.
(global-set-key
  [M-kanji]
  #'(lambda (arg)
      (interactive "P")
      (setq prefix-arg arg)))

;;
;; others
(defmacro wrap-function-to-control-input-method (fcn)
  `(advice-add ,fcn :around
               (lambda (orig-fun &rest args)
                 (let ((im current-input-method)
		       retval)
                   (deactivate-input-method)
                   (setq retval (apply orig-fun args))
                   (activate-input-method im)
		   retval))))

(wrap-function-to-control-input-method 'map-y-or-n-p)
(wrap-function-to-control-input-method 'y-or-n-p)
(wrap-function-to-control-input-method 'read-key-sequence)

;; disable W32-IME control during processing the timer handler
(advice-add 'timer-event-handler :around
            (lambda (orig-fun &rest args)
              (let ((w32-ime-buffer-switch-p nil))
                (apply orig-fun args))))

;; turn IME off when specifying a register
(eval-when-compile (require 'cl-macs))
(declare-function saved-read-key "register" (&optional prompt))
(declare-function register-read-with-preview-with-ime-off "register" (orig-fun &rest args))
(with-eval-after-load "register"
  (fset 'saved-read-key (symbol-function 'read-key))
  (defun read-key-with-ime-off (&optional prompt)
    (let ((im current-input-method)
	  (key))
      (deactivate-input-method)
      (setq key (saved-read-key prompt))
      (activate-input-method im)
      key))
  (defun register-read-with-preview-with-ime-off (orig-fun &rest args)
    (cl-letf (((symbol-function 'read-key)
	       (symbol-function 'read-key-with-ime-off)))
      (apply orig-fun args)))
  (advice-add 'register-read-with-preview :around #'register-read-with-preview-with-ime-off))

(provide 'smart-ime)
;; -*- mode: Emacs-Lisp; coding: euc-jp-unix -*-
