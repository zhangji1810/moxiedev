;;; 1010101010101010101010101010101010101010101010101010101010101010101010101010101
;;; 0101010101010101010101010101010101010101010101010101010101010101010101010101010
;;; 1   ___  ___          _     ______                                            1
;;; 0   |  \/  |         (_)    |  _  \              Open Source Tools,           0
;;; 1   | .  . | _____  ___  ___| | | |_____   __    Firmware, and HDL code for   1
;;; 0   | |\/| |/ _ \ \/ / |/ _ \ | | / _ \ \ / /    the Moxie processor core.    0
;;; 1   | |  | | (_) >  <| |  __/ |/ /  __/\ V /                                  1
;;; 0   \_|  |_/\___/_/\_\_|\___|___/ \___| \_/      http://moxielogic.org/blog   0
;;; 1                                                                             1
;;; 0101010101010101010101010101010101010101010101010101010101010101010101010101010
;;; 1010101010101010101010101010101010101010101010101010101010101010101010101010101

;;; Copyright (C) 2012  Anthony Green <green@moxielogic.com>
;;; Distrubuted under the terms of the GPL v3 or later.

;;; This script reads linux kernel instruction traces generated by
;;; "moxie-elf-run -t vmlinux" and produces a function call trace by
;;; looking up addresses in the kernel's symbol map, System.map, as
;;; generated by the kernel's build machinery.  Run it in the top
;;; level kernel build directory.
;;;
;;; Thanks for Zach Beane for quicklisp (which you'll need to install)
;;;

(ql:quickload "cl-ppcre")
(defpackage :mkt-grok
  (:use :cl :cl-user :cl-ppcre))


(defvar *symbol-map* nil)

;; Read the kernel's System.map file.  This tells us where functions
;; appear in memory. Build a datastructure that maps a memory address
;; to a kernel function.
(let ((in (open "System.map" :if-does-not-exist nil))
      (previous-address -1)
      (slist (list)))
  (when in
    (loop for line = (read-line in nil)
	  while line do (let ((s (cl-ppcre:split " " line)))
			  (let ((address (parse-integer (car s) :radix 16))
				(symbol (car (cdr (cdr s)))))
			    (if (not (eq address previous-address))
				(progn
				  (setf previous-address address)
				  (setf slist (cons (cons address symbol) slist))))))))
  (setf slist (cons (cons #xFFFFFFFF "**END**") slist))
  (setf *symbol-map* (make-array (length slist) :initial-contents slist)))

(defvar *last-function-match* 99)

(defun find-function-at (address)
  ; Check the last function match first...
  (if (and (<= (car (aref *symbol-map* *last-function-match*)) address)
	   (>= (car (aref *symbol-map* (- *last-function-match* 1))) address))
      (cdr (aref *symbol-map* *last-function-match*))
    ; No match.. let's do a binary search...
    (let ((low 0)
	  (high (1- (length *symbol-map*))))
      (do () ((< high low) 
	      (progn
		(setf *last-function-match* (+ (floor (/ (+ low high) 2)) 1))
		(cdr (aref *symbol-map* *last-function-match*))))
	(let* ((middle (floor (/ (+ low high) 2)))
	       (test-value (aref *symbol-map* middle)))
	  (cond ((< (car test-value) address)
		 (setf high (1- middle)))
		((> (car test-value) address)
		 (setf low (1+ middle)))
		(t (return (cdr test-value)))))))))

;; Fill and populate a hash table identifying "call" instructions.
(defvar *call-insn-hash* (make-hash-table :test 'equal))
(mapcar (lambda (insn) (setf (gethash insn *call-insn-hash*) t))
	'(" jmp" " jmpa" " jsr" " jsra" " swi"))

(defun is-call (insn)
  ;; Return t if insn is some sort of function call
  (gethash insn *call-insn-hash*))

(defvar *nest-level* -1)

(let ((in (open "trace.csv" :if-does-not-exist nil))
      (previous-function nil))
  (when in
    (loop for filepos = (file-position in)
	  for line = (read-line in nil)
 	  while line do (let ((s (cl-ppcre:split "," line)))
			  (cond
			    ((is-call (car (cdr s)))
			     (let ((fn (find-function-at
					(parse-integer (string-left-trim "0x" (car s)) :radix 16))))
			       (if (not (eq fn previous-function))
				   (progn
				     (setf *nest-level* (+ *nest-level* 1))
				     (setf previous-function fn)
				     (format t "~V,,,VA~A~%" *nest-level* #\Space "" fn)))))
			    ((equal " ret" (car (cdr s)))
			     (progn
			       (setf *nest-level* (- *nest-level* 1))
			       (format t "RET~%"))))))
    (close in)))

(quit)

