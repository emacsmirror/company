;;; core-tests.el --- company-mode tests  -*- lexical-binding: t -*-

;; Copyright (C) 2015-2025  Free Software Foundation, Inc.

;; Author: Dmitry Gutov

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

(require 'company-tests)

(ert-deftest company-good-prefix ()
  (should (eq t (company--good-prefix-p "!@#$%" 5)))
  (should (eq nil (company--good-prefix-p "abcd" 5)))
  (should (eq nil (company--good-prefix-p 'stop 5)))
  (should (eq t (company--good-prefix-p '("foo" . 5) 5)))
  (should (eq nil (company--good-prefix-p '("foo" . 4) 5)))
  (should (eq t (company--good-prefix-p '("foo" . t) 5))))

(ert-deftest company--manual-prefix-set-and-unset ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abc" "abd")))))))
      (company-manual-begin)
      (should (equal "ab" company--manual-prefix))
      (company-abort)
      (should (null company--manual-prefix)))))

(ert-deftest company-auto-begin-unique-cancels ()
  (with-temp-buffer
    (insert "abc")
    (company-mode)
    (let (company-frontends
          (company-abort-on-unique-match t)
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abc")))))))
      (company-auto-begin)
      (should (equal nil company-candidates)))))

(ert-deftest company-auto-begin-unique-cancels-not ()
  (with-temp-buffer
    (insert "abc")
    (company-mode)
    (let (company-frontends
          company-abort-on-unique-match
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abc")))))))
      (company-auto-begin)
      (should (equal '("abc") company-candidates)))))

(ert-deftest company-manual-begin-unique-shows-completion ()
  (with-temp-buffer
    (insert "abc")
    (company-mode)
    (let (company-frontends
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abc")))))))
      (company-manual-begin)
      (should (equal '("abc") company-candidates)))))

(ert-deftest company-prefix-min-length ()
  (let ((company-minimum-prefix-length 5)
        (company-selection-changed t))    ;has not effect
    (should (= (company--prefix-min-length) 5))
    (let ((company-abort-manual-when-too-short t)
          (company--manual-prefix "abc")) ;manual begin from this prefix
      (should (= (company--prefix-min-length) 3)))
    (let ((company-abort-manual-when-too-short t)
          (company--manual-prefix '("abc" . 2)))
      (should (= (company--prefix-min-length) 2)))
    (let ((company-abort-manual-when-too-short t)
          (company--manual-prefix '("abc" . t)))
      (should (= (company--prefix-min-length) 3)))
    (let ((company--manual-prefix "abc"))
      (should (= (company--prefix-min-length) 0)))))

(ert-deftest company-common-with-non-prefix-completion ()
  (let ((company-backend #'ignore)
        (company-prefix "abc")
        company-candidates
        company-candidates-length
        company-candidates-cache
        company-common)
    (company-update-candidates '("abc" "def-abc"))
    (should (equal company-common ""))
    (company-update-candidates '("abc" "abe-c"))
    (should (equal company-common "ab"))
    (company-update-candidates '("abcd" "abcde" "abcdf"))
    (should (equal "abcd" company-common))))

(ert-deftest company-multi-backend-with-lambdas ()
  (let ((company-backend
         (list (lambda (command &optional _ &rest _r)
                 (cl-case command
                   (prefix "z")
                   (candidates '("a" "b"))))
               (lambda (command &optional _ &rest _r)
                 (cl-case command
                   (prefix "z")
                   (candidates '("c" "d")))))))
    (company-call-backend 'set-min-prefix 1)
    (should (equal (company-call-backend 'candidates "z") '("a" "b" "c" "d")))))

(ert-deftest company-multi-backend-with-empty-prefixes ()
  (let ((company-backend
         (list (lambda (command &optional _ &rest _r)
                 (cl-case command
                   (prefix "")
                   (candidates '("a" "b"))))
               (lambda (command &optional _ &rest _r)
                 (cl-case command
                   (prefix "")
                   (candidates '("c" "d")))))))
    (should (equal (company-call-backend 'prefix) '("" nil 0)))))

(ert-deftest company-multi-backend-none-applicable ()
  (let ((company-backend (list #'ignore #'ignore)))
    (should (null (company-call-backend 'prefix)))))

(ert-deftest company-multi-backend-dispatches-separate-prefix-to-backends ()
  (let ((company-backend
         (list (lambda (command &optional arg &rest _r)
                 (cl-case command
                   (prefix (cons "z" t))
                   (candidates
                    (should (equal arg "z"))
                    '("a" "b"))))
               (lambda (command &optional arg &rest _r)
                 (cl-case command
                   (prefix "t")
                   (candidates
                    (should (equal arg "t"))
                    '("c" "d")))))))
    (company-call-backend 'set-min-prefix 1)
    (should (equal (company-call-backend 'candidates "z") '("a" "b" "c" "d")))))

(ert-deftest company-multi-backend-remembers-candidate-backend ()
  (let ((company-backend
         (list (lambda (command &rest _)
                 (cl-case command
                   (prefix "")
                   (ignore-case nil)
                   (annotation "1")
                   (candidates '("a" "c"))
                   (post-completion "13")))
               (lambda (command &rest _)
                 (cl-case command
                   (prefix "")
                   (ignore-case t)
                   (annotation "2")
                   (candidates '("b" "d"))
                   (post-completion "42")))
               (lambda (command &rest _)
                 (cl-case command
                   (prefix "")
                   (annotation "3")
                   (candidates '("e"))
                   (post-completion "74"))))))
    (company-call-backend 'set-min-prefix 0)
    (let ((candidates (company-calculate-candidates "" nil nil)))
      (should (equal candidates '("a" "b" "c" "d" "e")))
      (should (equal t (company-call-backend 'ignore-case)))
      (should (equal "1" (company-call-backend 'annotation (nth 0 candidates))))
      (should (equal "2" (company-call-backend 'annotation (nth 1 candidates))))
      (should (equal "13" (company-call-backend 'post-completion (nth 2 candidates))))
      (should (equal "42" (company-call-backend 'post-completion (nth 3 candidates))))
      (should (equal "3" (company-call-backend 'annotation (nth 4 candidates))))
      (should (equal "74" (company-call-backend 'post-completion (nth 4 candidates)))))))

(ert-deftest company-multi-backend-handles-keyword-with ()
  (let ((primo (lambda (command &rest _)
                 (cl-case command
                   (prefix "a")
                   (candidates '("abb" "abc" "abd")))))
        (secundo (lambda (command &rest _)
                   (cl-case command
                     (prefix "a")
                     (candidates '("acc" "acd"))))))
    (let ((company-backend (list 'ignore 'ignore :with secundo)))
      (should (null (company-call-backend 'prefix))))
    (let ((company-backend (list 'ignore primo :with secundo)))
      (should (equal '("a" nil 1) (company-call-backend 'prefix)))
      (company-call-backend 'set-min-prefix 1)
      (should (equal '("abb" "abc" "abd" "acc" "acd")
                     (company-call-backend 'candidates "a"))))))

(ert-deftest company-multi-backend-handles-keyword-separate ()
  (let ((one (lambda (command &rest _)
               (cl-case command
                 (prefix "a")
                 (candidates (list "aa" "ca" "ba")))))
        (two (lambda (command &rest _)
               (cl-case command
                 (prefix "a")
                 (candidates (list "bb" "ab")))))
        (tri (lambda (command &rest _)
               (cl-case command
                 (prefix "a")
                 (sorted t)
                 (candidates (list "cc" "bc" "ac"))))))
    (let ((company-backend (list one two tri :separate)))
      (should (company-call-backend 'sorted))
      (should-not (company-call-backend 'duplicates))
      (company-call-backend 'set-min-prefix 1)
      (should (equal '("aa" "ba" "ca" "ab" "bb" "cc" "bc" "ac")
                     (company-call-backend 'candidates "a"))))))

(ert-deftest company-multi-backend-handles-length-overrides-separately ()
  (let ((one (lambda (command &rest _)
               (cl-case command
                 (prefix "a")
                 (candidates (list "aa" "ca" "ba")))))
        (two (lambda (command &rest _)
               (cl-case command
                 (prefix (cons "a" 2))
                 (candidates (list "bb" "ab")))))
        (tri (lambda (command &rest _)
               (cl-case command
                 (prefix "")
                 (candidates (list "cc" "bc" "ac"))))))
    (company-call-backend 'set-min-prefix 2)
    (let ((company-backend (list one two tri)))
      (should (equal '("bb" "ab")
                     (company-call-backend 'candidates "a"))))
    (company-call-backend 'set-min-prefix 1)
    (let ((company-backend (list one two tri)))
      (should (equal '("aa" "ca" "ba" "bb" "ab")
                     (company-call-backend 'candidates "a"))))))

(ert-deftest company-multi-backend-handles-clears-cache-when-needed ()
  (let* ((one (lambda (command &rest _)
                (cl-case command
                  (prefix "aa")
                  (candidates (list "aa")))))
         (two (lambda (command &rest _)
                (cl-case command
                  (prefix (cons "aa" t))
                  (candidates (list "aab" )))))
         (tri (lambda (command &rest _)
                (cl-case command
                  (prefix "")
                  (candidates (list "aac")))))
         (company--multi-uncached-backends (list one tri)))
    (let ((company-backend (list one two tri)))
      (company-call-backend 'set-min-prefix 2)
      (should
       (equal (company-call-backend 'no-cache) t))
      (should (equal company--multi-uncached-backends (list tri)))
      (should (equal '("aa" "aab")
                     (company-call-backend 'candidates "aa"))))))

(ert-deftest company-multi-backend-chooses-longest-prefix-length ()
  (let* ((one (lambda (command &rest _)
                (cl-case command
                  (prefix "aa")
                  (candidates (list "aa")))))
         (two (lambda (command &rest _)
                (cl-case command
                  (prefix (cons "aa" t))
                  (candidates (list "aab" )))))
         (tri (lambda (command &rest _)
                (cl-case command
                  (prefix "")
                  (candidates (list "aac")))))
         (fur (lambda (command &rest _)
                (cl-case command
                  (prefix (cons "aa" 3))
                  (candidates (list "aac")))))
         (fiv (lambda (command &rest _)
                (cl-case command
                  (prefix (cons "aa" 1))
                  (candidates (list "aac")))))
         (company--multi-uncached-backends (list one tri)))
    (let ((company-backend (list one tri fur)))
      (should
       (equal
        '("aa" nil 3)
        (company-call-backend 'prefix))))
    (let ((company-backend (list one two tri fur)))
      (should
       (equal
        '("aa" nil t)
        (company-call-backend 'prefix))))
    (let ((company-backend (list one fiv)))
      (should
       (equal
        '("aa" nil 2)
        (company-call-backend 'prefix))))))

(ert-deftest company-multi-backend-supports-different-suffixes ()
  (let* ((one (lambda (command &rest args)
                (cl-case command
                  (prefix '("a" "b"))
                  (candidates
                   (should (equal args '("a" "b")))
                   '("a1b")))))
         (two (lambda (command &rest args)
                (cl-case command
                  (prefix "a")
                  (candidates
                   (should (equal args '("a" "")))
                   '("a2")))))
         (tri (lambda (command &rest args)
                (cl-case command
                  (prefix '("a" ""))
                  (candidates
                   (should (equal args '("a" "")))
                   '("a3")))))
         (company-backend (list one two tri)))
    (should
     (equal '("a" "b" 1)
            (company-call-backend 'prefix)))
    (should
     (equal '("a1b" "a2" "a3")
            (company-call-backend 'candidates "a" "b")))))

(ert-deftest company-multi-backend-dispatches-adjust-boundaries ()
  (let* ((one (lambda (command &rest _args)
                (cl-case command
                  (prefix '("a" ""))
                  (candidates
                   '("a1b")))))
         (tri (lambda (command &rest args)
                (cl-case command
                  (prefix '("aa" "bcd"))
                  (adjust-boundaries
                   (should (equal args
                                  '("a3" "aa" "bcd")))
                   (cons "a" "bc"))
                  (candidates
                   '("a3")))))
         (company-backend (list one tri))
         (company-point (point))
         (candidates (company-call-backend 'candidates "a" "")))
    (should
     (equal '("aa" "bcd" 2)
            (company-call-backend 'prefix)))
    (should
     (equal (cons "a" "bc")
            (company-call-backend 'adjust-boundaries
                                  (car (member "a3" candidates))
                                  "aa" "bcd")))
    (should
     (equal (cons "a" "")
            (company-call-backend 'adjust-boundaries
                                  (car (member "a1b" candidates))
                                  "aa" "bcd")))))

(ert-deftest company-multi-backend-adjust-boundaries-default ()
  (let* ((one (lambda (command &rest _args)
                (cl-case command
                  (prefix '("a" "1"))
                  (candidates
                   '("ab1")))))
         (tri (lambda (command &rest _args)
                (cl-case command
                  (prefix '("aa" "bcd"))
                  (candidates
                   '("aa3bb"
                     "aa3bcd")))))
         (company-backend (list one tri))
         (company-point (point))
         (candidates (company-call-backend 'candidates "a" "")))
    (should
     (equal (cons "a" "1")
            (company-call-backend 'adjust-boundaries
                                  (car (member "ab1" candidates))
                                  "aa" "bcd")))
    (should
     (equal (cons "aa" "")
            (company-call-backend 'adjust-boundaries
                                  (car (member "aa3bb" candidates))
                                  "aa" "bcd")))
    (should
     (equal (cons "aa" "bcd")
            (company-call-backend 'adjust-boundaries
                                  (car (member "aa3bcd" candidates))
                                  "aa" "bcd")))
    ))

(ert-deftest company-multi-backend-combines-expand-common ()
  (let* ((one (lambda (command &rest _args)
                (cl-case command
                  (prefix '("a" ""))
                  (expand-common (cons "ab" "")))))
         (two (lambda (command &rest _args)
                (cl-case command
                  (prefix '("aa" "bcd"))
                  (expand-common (cons "aab" "bcd")))))
         (tri (lambda (command &rest _args)
                (cl-case command
                  (prefix '("aa" "bcd"))
                  (expand-common 'no-match))))
         (company-backend (list one two tri))
         (company-point (point)))
    (company-call-backend 'set-min-prefix 1)
    (should
     (equal '("aab" . "bcd")
            (company-call-backend 'expand-common "aa" "bcd")))))

(ert-deftest company-multi-backend-expand-common-returns-no-match ()
  (let* ((one (lambda (command &rest _args)
                (cl-case command
                  (prefix '("a" ""))
                  (expand-common 'no-match))))
         (two (lambda (command &rest _args)
                (cl-case command
                  (prefix '("aa" "bcd"))
                  (expand-common 'no-match))))
         (company-backend (list one two))
         (company-point (point)))
    (company-call-backend 'set-min-prefix 1)
    (should
     (equal 'no-match
            (company-call-backend 'expand-common "aa" "bcd")))))

(ert-deftest company-multi-backend-expand-common-keeps-current ()
  (let* ((one (lambda (command &rest _args)
                (cl-case command
                  (prefix '("a" ""))
                  (expand-common (cons "ab" "")))))
         (two (lambda (command &rest _args)
                (cl-case command
                  (prefix '("a" ""))
                  (expand-common (cons "ac" "")))))
         (company-backend (list one two))
         (company-point (point)))
    (company-call-backend 'set-min-prefix 1)
    (should
     (equal '("a" . "")
            (company-call-backend 'expand-common "a" "")))))

(ert-deftest company-begin-backend-failure-doesnt-break-company-backends ()
  (with-temp-buffer
    (insert "a")
    (company-mode)
    (should-error
     (company-begin-backend #'ignore))
    (let (company-frontends
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix "a")
                     (candidates '("a" "ab" "ac")))))))
      (let (this-command)
        (company-call 'complete))
      (should (eq 3 company-candidates-length)))))

(ert-deftest company-require-match-explicit ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          (company-require-match 'company-explicit-action-p)
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abc" "abd")))))))
      (let (this-command)
        (company-complete))
      (let ((last-command-event ?e))
        (company-call 'self-insert-command 1))
      (should (eq 2 company-candidates-length))
      (should (eq 3 (point))))))

(ert-deftest company-dont-require-match-when-idle ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          (company-minimum-prefix-length 2)
          (company-require-match 'company-explicit-action-p)
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abc" "abd")))))))
      (company-idle-begin (current-buffer) (selected-window)
                          (buffer-chars-modified-tick) (point))
      (should (eq 2 company-candidates-length))
      (let ((last-command-event ?e))
        (company-call 'self-insert-command 1))
      (should (eq nil company-candidates-length))
      (should (eq 4 (point))))))

(ert-deftest company-dont-require-match-if-was-a-match-and-old-prefix-ended ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          company-insertion-on-trigger
          (company-require-match t)
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (company-grab-word))
                     (candidates '("abc" "ab" "abd"))
                     (sorted t))))))
      (let (this-command)
        (company-complete))
      (let ((last-command-event ?e))
        (company-call 'self-insert-command 1))
      (should (eq 3 company-candidates-length))
      (should (eq 3 (point)))
      (let ((last-command-event ? ))
        (company-call 'self-insert-command 1))
      (should (null company-candidates-length))
      (should (eq 4 (point))))))

(ert-deftest company-dont-require-match-if-was-a-match-and-new-prefix-is-stop ()
  (with-temp-buffer
    (company-mode)
    (insert "c")
    (let (company-frontends
          (company-require-match t)
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (if (> (point) 2)
                                 'stop
                               (buffer-substring (point-min) (point))))
                     (candidates '("a" "b" "c")))))))
      (let (this-command)
        (company-complete))
      (should (eq 3 company-candidates-length))
      (let ((last-command-event ?e))
        (company-call 'self-insert-command 1))
      (should (not company-candidates)))))

(ert-deftest company-should-complete-whitelist ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          company-begin-commands
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abc" "abd")))))))
      (let ((company-continue-commands nil))
        (let (this-command)
          (company-complete))
        (company-call 'backward-delete-char 1)
        (should (null company-candidates-length)))
      (let ((company-continue-commands '(backward-delete-char)))
        (let (this-command)
          (company-complete))
        (company-call 'backward-delete-char 1)
        (should (eq 2 company-candidates-length))))))

(ert-deftest company-should-complete-blacklist ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          company-begin-commands
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abc" "abd")))))))
      (let ((company-continue-commands '(not backward-delete-char)))
        (let (this-command)
          (company-complete))
        (company-call 'backward-delete-char 1)
        (should (null company-candidates-length)))
      (let ((company-continue-commands '(not backward-delete-char-untabify)))
        (let (this-command)
          (company-complete))
        (company-call 'backward-delete-char 1)
        (should (eq 2 company-candidates-length))))))

(ert-deftest company-backspace-into-bad-prefix ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          (company-minimum-prefix-length 2)
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abcd" "abef")))))))
      (let ((company-idle-delay 'now))
        (company-auto-begin))
      (company-call 'backward-delete-char-untabify 1)
      (should (string= "a" (buffer-string)))
      (should (null company-candidates)))))

(ert-deftest company-insertion-on-trigger-explicit ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          (company-insertion-on-trigger 'company-explicit-action-p)
          (company-insertion-triggers '(? ))
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abcd" "abef")))))))
      (let (this-command)
        (company-complete))
      (let ((last-command-event ? ))
        (company-call 'self-insert-command 1))
      (should (string= "abcd " (buffer-string))))))

(ert-deftest company-insertion-on-trigger-with-electric-pair ()
  (with-temp-buffer
    (insert "foo(ab)")
    (forward-char -1)
    (company-mode)
    (let (company-frontends
          (company-insertion-on-trigger t)
          (company-insertion-triggers '(? ?\)))
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring 5 (point)))
                     (candidates '("abcd" "abef"))))))
          (electric-pair electric-pair-mode))
      (unwind-protect
          (progn
            (electric-pair-mode)
            (let (this-command)
              (company-complete))
            (let ((last-command-event ?\)))
              (company-call 'self-insert-command 1)))
        (unless electric-pair
          (electric-pair-mode -1)))
      (should (string= "foo(abcd)" (buffer-string))))))

(ert-deftest company-no-insertion-on-trigger-when-idle ()
  (with-temp-buffer
    (insert "ab")
    (company-mode)
    (let (company-frontends
          (company-insertion-on-trigger 'company-explicit-action-p)
          (company-insertion-triggers '(? ))
          (company-minimum-prefix-length 2)
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abcd" "abef")))))))
      (company-idle-begin (current-buffer) (selected-window)
                          (buffer-chars-modified-tick) (point))
      (let ((last-command-event ? ))
        (company-call 'self-insert-command 1))
      (should (string= "ab " (buffer-string))))))

(ert-deftest company-clears-explicit-action-when-no-matches ()
  (with-temp-buffer
    (company-mode)
    (let (company-frontends
          company-backends)
      (company-call 'manual-begin) ;; fails
      (should (null company-candidates))
      (should (null (company-explicit-action-p))))))

(ert-deftest company-ignore-case-replaces-prefix ()
  (with-temp-buffer
    (company-mode)
    (let (company-frontends
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abcd" "abef"))
                     (ignore-case t))))))
      (insert "A")
      (let (this-command)
        (company-complete))
      (should (string= "ab" (buffer-string)))
      (delete-char -2)
      (insert "A") ; hack, to keep it in one test
      (company-complete-selection)
      (should (string= "abcd" (buffer-string))))))

(ert-deftest company-ignore-case-with-keep-prefix ()
  (with-temp-buffer
    (insert "AB")
    (company-mode)
    (let (company-frontends
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("abcd" "abef"))
                     (ignore-case 'keep-prefix))))))
      (let (this-command)
        (company-complete))
      (company-complete-selection)
      (should (string= "ABcd" (buffer-string))))))

(ert-deftest company-non-prefix-completion ()
  (with-temp-buffer
    (insert "tc")
    (company-mode)
    (let (company-frontends
          (company-backends
           (list (lambda (command &rest _)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("tea-cup" "teal-color")))))))
      (let (this-command)
        (company-complete))
      (should (string= "tc" (buffer-string)))
      (company-complete-selection)
      (should (string= "tea-cup" (buffer-string))))))

(ert-deftest company-complete-restarts-in-new-field ()
  (with-temp-buffer
    (insert "foo")
    (company-mode)
    (let (company-frontends
          (company-backends
           (list (lambda (command &optional _arg &rest rest)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (adjust-boundaries
                      (if (string-suffix-p "/" (car rest))
                          (cons "" (nth 1 rest))
                        (cons (car rest) (nth 1 rest))))
                     (candidates '("cc/" "aa1" "bb2"))
                     (sorted t))))))
      (let (this-command)
        (company-complete))
      (should (string= "foo" (buffer-string)))
      (company-complete-selection)
      (should (string= "cc/" (buffer-string)))
      (should (equal company-candidates '("cc/" "aa1" "bb2"))))))

(ert-deftest company-complete-no-restart-in-old-field ()
  (with-temp-buffer
    (insert "foo")
    (company-mode)
    (let (company-frontends
          (company-backends
           (list (lambda (command &rest _rest)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("cc/" "aa1" "bb2"))
                     (sorted t))))))
      (let (this-command)
        (company-complete))
      (company-complete-selection)
      (should (string= "cc/" (buffer-string)))
      (should (null company-candidates)))))

(ert-deftest company-complete-no-restart-after-post-completion-change ()
  (with-temp-buffer
    (insert "foo")
    (company-mode)
    (let (company-frontends
          (company-backends
           (list (lambda (command &optional _arg &rest rest)
                   (cl-case command
                     (prefix (buffer-substring (point-min) (point)))
                     (candidates '("cc/" "aa1" "bb2"))
                     (adjust-boundaries
                      (if (string-suffix-p "/" (car rest))
                          (cons "" (nth 1 rest))
                        (cons (car rest) (nth 1 rest))))
                     (post-completion (insert "bar/"))
                     (sorted t))))))
      (let (this-command)
        (company-complete))
      (company-complete-selection)
      (should (string= "cc/bar/" (buffer-string)))
      (should (null company-candidates)))))

(defvar ct-sorted nil)

;; FIXME: When Emacs 29+ only: just replace with equal-including-properties.
(defun ct-equal-including-properties (list1 list2)
  (or (and (not list1) (not list2))
      (and (company--equal-including-properties (car list1) (car list2))
           (ct-equal-including-properties (cdr list1) (cdr list2)))))

(ert-deftest company-strips-duplicates-returns-nil ()
  (should (null (company--preprocess-candidates nil))))

(ert-deftest company-strips-duplicates-within-groups ()
  (let* ((kvs '(("a" . "b")
                ("a" . nil)
                ("a" . "b")
                ("a" . "c")
                ("a" . "b")
                ("b" . "c")
                ("b" . nil)
                ("a" . "b")))
         (fn (lambda (kvs)
               (mapcar (lambda (kv) (propertize (car kv) 'ann (cdr kv)))
                       kvs)))
         (company-backend
          (lambda (command &optional arg)
            (pcase command
              (`prefix "")
              (`sorted ct-sorted)
              (`duplicates t)
              (`annotation (get-text-property 0 'ann arg)))))
         (reference '(("a" . "b")
                      ("a" . nil)
                      ("a" . "c")
                      ("b" . "c")
                      ("b" . nil)
                      ("a" . "b"))))
    (let ((ct-sorted t))
      (should (ct-equal-including-properties
               (company--preprocess-candidates (funcall fn kvs))
               (funcall fn reference))))
    (should (ct-equal-including-properties
             (company--preprocess-candidates (funcall fn kvs))
             (funcall fn (butlast reference))))))

;;; Row and column

(ert-deftest company-column-with-composition ()
  :tags '(interactive)
  (with-temp-buffer
    (save-window-excursion
      (set-window-buffer nil (current-buffer))
      (insert "lambda ()")
      (compose-region 1 (1+ (length "lambda")) "\\")
      (should (= (company--column) 4)))))

(ert-deftest company-column-with-line-prefix ()
  :tags '(interactive)
  (with-temp-buffer
    (save-window-excursion
      (set-window-buffer nil (current-buffer))
      (insert "foo")
      (put-text-property (point-min) (point) 'line-prefix "  ")
      (should (= (company--column) 5)))))

(ert-deftest company-column-with-line-prefix-on-empty-line ()
  :tags '(interactive)
  (with-temp-buffer
    (save-window-excursion
      (set-window-buffer nil (current-buffer))
      (insert "\n")
      (forward-char -1)
      (put-text-property (point-min) (point-max) 'line-prefix "  ")
      (should (= (company--column) 2)))))

(ert-deftest company-column-with-tabs ()
  :tags '(interactive)
  (with-temp-buffer
    (save-window-excursion
      (set-window-buffer nil (current-buffer))
      (insert "|\t|\t|\t(")
      (let ((tab-width 8))
        (should (= (company--column) 25))))))

(ert-deftest company-row-with-header-line-format ()
  :tags '(interactive)
  (with-temp-buffer
    (save-window-excursion
      (set-window-buffer nil (current-buffer))
      (should (= (company--row) 0))
      (setq header-line-format "aaaaaaa")
      (should (= (company--row) 0)))))

;; Avoid compilation warnings on Emacs 25.
(declare-function display-line-numbers-mode "display-line-numbers")
(declare-function line-number-display-width "indent.c")

(ert-deftest company-column-with-line-numbers-display ()
  :tags '(interactive)
  (skip-unless (fboundp 'display-line-numbers-mode))
  (with-temp-buffer
    (display-line-numbers-mode)
    (save-window-excursion
      (set-window-buffer nil (current-buffer))
      (should (= (company--column) 0)))))

(ert-deftest company-row-and-column-with-line-numbers-display ()
  :tags '(interactive)
  (skip-unless (fboundp 'display-line-numbers-mode))
  (with-temp-buffer
    (display-line-numbers-mode)
    (insert (make-string (+ (company--window-width) (line-number-display-width)) ?a))
    (insert ?\n)
    (save-window-excursion
      (set-window-buffer nil (current-buffer))
      (should (= (company--column) 0))
      (should (= (company--row) 2)))))

(ert-deftest company-set-nil-selection ()
  (let ((company-selection 1)
        (company-candidates-length 10)
        (company-selection-changed nil)
        (company-frontends nil))
    (company-set-selection nil)
    (should (eq company-selection nil))
    (should (eq company-selection-changed t))))

(ert-deftest company-update-candidates-nil-selection ()
  (let ((company-selection nil)
        (company-backend #'ignore)
        company-candidates
        company-candidates-length
        company-candidates-cache
        company-common
        company-selection-default
        (company-prefix "ab"))
    (company-update-candidates '("abcd" "abcde" "abcdf"))
    (should (null company-selection)))

  (let* ((company-selection 1)
         (company-backend #'ignore)
         (company-candidates '("abc" "abdc" "abe"))
         company-candidates-length
         company-candidates-cache
         company-common
         company-selection-default
         (company-prefix "ab")
         (company-selection-changed t))
    (company-update-candidates '("abcd" "abcde" "abcdf"))
    (should (null company-selection))))

(ert-deftest company-select-next ()
  (cl-letf (((symbol-function 'company-manual-begin) (lambda () t))
            (company-selection 1)
            (company-candidates-length 10)
            (company-selection-default 0)
            (company-selection-wrap-around nil)
            (company-frontends nil))
    ;; Not wrap
    (company-select-next 5)
    (should (eq company-selection 6))

    (company-select-next 5)
    (should (eq company-selection 9))

    (company-select-next -2)
    (should (eq company-selection 7))

    ;; Nil selection
    (setq company-selection nil)
    (company-select-next 5)
    (should (eq company-selection 5))

    (setq company-selection nil)
    (company-select-next -1)
    (should (eq company-selection 0))

    ;; Wrap
    (setq company-selection-wrap-around t)
    (setq company-selection 7)
    (company-select-next 5)
    (should (eq company-selection 2))

    ;; Nil selection
    (setq company-selection nil)
    (company-select-next 11)
    (should (eq company-selection 1))

    (setq company-selection nil)
    (company-select-next -10)
    (should (eq company-selection 0))))

(ert-deftest company-select-next-default-selection-nil ()
  (cl-letf (((symbol-function 'company-manual-begin) (lambda () t))
            (company-selection 1)
            (company-candidates-length 10)
            (company-selection-default nil)
            (company-selection-wrap-around nil)
            (company-frontends nil))
    ;; Not wrap
    (company-select-next 5)
    (should (eq company-selection 6))

    (company-select-next 5)
    (should (eq company-selection 9))

    (company-select-next -10)
    (should (eq company-selection nil))

    ;; Nil selection
    (setq company-selection nil)
    (company-select-next 5)
    (should (eq company-selection 4))

    (setq company-selection nil)
    (company-select-next -1)
    (should (eq company-selection nil))

    ;; Wrap
    (setq company-selection-wrap-around t)
    (setq company-selection 7)
    (company-select-next 5)
    (should (eq company-selection 1))

    (setq company-selection 0)
    (company-select-next -1)
    (should (eq company-selection nil))

    (setq company-selection 0)
    (company-select-next -11)
    (should (eq company-selection 0))

    ;; Nil selection
    (setq company-selection nil)
    (company-select-next 11)
    (should (eq company-selection nil))

    (setq company-selection nil)
    (company-select-next -10)
    (should (eq company-selection 0))))

(ert-deftest company-capf-completions ()
  (let ((table '("ab-de-b" "ccc" "abc-de-b")))
    (let ((completion-styles '(partial-completion)))
      (should
       (equal (company--capf-completions "ab-d" "b" table)
              '((:completions . ("ab-de-b" "abc-de-b"))
                (:boundaries . ("ab-d" . "b"))))))
    (let ((completion-styles '(emacs22)))
      (should
       (equal (company--capf-completions "ab-d" "b" table)
              '((:completions . ("ab-de-b"))
                (:boundaries . ("ab-d" . ""))))))))

;;; core-tests.el ends here.
