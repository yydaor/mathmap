;; ops.lisp

;; MathMap

;; Copyright (C) 2004-2007 Mark Probst

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, you can either send email to this
;; program's maintainer or write to: The Free Software Foundation,
;; Inc.; 675 Massachusetts Avenue; Cambridge, MA 02139, USA.

(in-package :mathmap)

;;; types
(defstruct (rt-type (:constructor make-rt-type
				  (name c-type &key print-info elements printer comparer)))
  name
  c-type
  print-info
  elements
  printer
  comparer)

(defun rt-type-c-define (type)
  (format nil "TYPE_~A" (ucs (rt-type-name type))))

(defparameter *types*
  (list
   (make-rt-type nil nil
		 :print-info '("NIL" "NIL" ()))
   (make-rt-type 'int "int"
		 :print-info '("%d" "%d" ("~A")))
   (make-rt-type 'float "float"
		 :print-info '("%f" "%f" ("~A")))
   (make-rt-type 'complex "complex float"
		 :print-info '("%f + %f i"
			       "COMPLEX(%f,%f)"
			       ("crealf(~A)" "cimagf(~A)")))
   (make-rt-type 'color "color_t"
		 :print-info '("(%d,%d,%d,%d)" "MAKE_RGBA_COLOR(%d,%d,%d,%d)"
			       ("RED(~A)" "GREEN(~A)" "BLUE(~A)" "ALPHA(~A)")))
   (make-rt-type 'image "image_t *"
		 :printer "print_image"
		 :comparer "images_equal")
   (make-rt-type 'tuple "float *"
		 :printer "print_tuple"
		 :comparer "tuples_equal")
   (make-rt-type 'gsl-matrix "gsl_matrix *"
		 :print-info '("***MATRIX***" "***MATRIX***" ()))
   (make-rt-type 'v2 "mm_v2_t"
		 :print-info '("[%f,%f]" "MAKE_V2(%f,%f)"
			       ("~A.v[0]" "~A.v[1]"))
		 :elements '("v[0]" "v[1]"))
   (make-rt-type 'v3 "mm_v3_t"
		 :print-info '("[%f,%f,%f]" "MAKE_V3(%f,%f,%f)"
			       ("~A.v[0]" "~A.v[1]" "~A.v[2]"))
		 :elements '("v[0]" "v[1]" "v[2]"))
   (make-rt-type 'm2x2 "mm_m2x2_t"
		 :print-info '("[[%f,%f],[%f,%f]]" "MAKE_M2X2(%f,%f,%f,%f)"
			       ("~A.a00" "~A.a01" "~A.a10" "~A.a11"))
		 :elements '("a00" "a01" "a10" "a11"))))

(defun rt-type-with-name (name)
  (find name *types* :key #'rt-type-name))

(defparameter *int-type* (rt-type-with-name 'int))
(defparameter *float-type* (rt-type-with-name 'float))
(defparameter *complex-type* (rt-type-with-name 'complex))

(defparameter *max-float-types* (list *int-type* *float-type*))
(defparameter *max-types* (list *int-type* *float-type* *complex-type*))

;;; ops
(defstruct op
  name c-define c-name interpreter-c-name type-prop type pure foldable arg-types)

(defun op-arity (op)
  (length (op-arg-types op)))

(defparameter *operators* nil)

(defun defop (name arity c-name
	      &key (interpreter-c-name nil) (c-define nil) (type-prop 'const) (type 'float)
	      (pure t) (foldable t) (arg-type 'float) (arg-types nil))
  (let ((c-define (if (null c-define)
		    (string-concat "OP_" (ucs name))
		  c-define))
	(arg-types (if (null arg-types)
		       (map-times arity #'(lambda (i) (rt-type-with-name arg-type)))
		       (progn
			 (assert (= (length arg-types) arity))
			 (mapcar #'rt-type-with-name arg-types))))
	(interpreter-c-name (if (null interpreter-c-name)
				c-name
				interpreter-c-name)))
    (push (make-op :name name
		   :c-define c-define
		   :c-name c-name
		   :interpreter-c-name interpreter-c-name
		   :type-prop type-prop
		   :type (rt-type-with-name type)
		   :pure pure
		   :foldable (if pure foldable nil)
		   :arg-types arg-types)
	  *operators*)))

(defop 'nop 0 "NOP" :type 'int)

(defop 'int-to-float 1 "INT2FLOAT" :type 'float :arg-type 'int)
(defop 'float-to-int 1 "FLOAT2INT" :type 'int :arg-type 'float)
(defop 'int-to-complex 1 "INT2COMPLEX" :type 'complex :arg-type 'int)
(defop 'float-to-complex 1 "FLOAT2COMPLEX" :type 'complex :arg-type 'float)

(defop '+ 2 "ADD" :type-prop 'max :type nil :c-define "OP_ADD")
(defop '- 2 "SUB" :type-prop 'max :type nil :c-define "OP_SUB")
(defop '- 1 "NEG" :type-prop 'max :type nil :c-define "OP_NEG")
(defop '* 2 "MUL" :type-prop 'max :type nil :c-define "OP_MUL")
(defop '/ 2 "DIV" :c-define "OP_DIV")
(defop '% 2 "MOD" :c-define "OP_MOD")

(defop 'abs 1 "fabs" :type-prop 'max-float :type nil)
(defop 'min 2 "MIN" :type-prop 'max-float :type nil)
(defop 'max 2 "MAX" :type-prop 'max-float :type nil)

(defop 'sqrt 1 "sqrt")
(defop 'hypot 2 "hypot")
(defop 'sin 1 "sin")
(defop 'cos 1 "cos")
(defop 'tan 1 "tan")
(defop 'asin 1 "asin")
(defop 'acos 1 "acos")
(defop 'atan 1 "atan")
(defop 'atan2 2 "atan2")
(defop 'pow 2 "pow")
(defop 'exp 1 "exp")
(defop 'log 1 "log")
(defop 'sinh 1 "sinh")
(defop 'cosh 1 "cosh")
(defop 'tanh 1 "tanh")
(defop 'asinh 1 "asinh")
(defop 'acosh 1 "acosh")
(defop 'atanh 1 "atanh")
(defop 'gamma 1 "GAMMA")
(defop 'beta 2 "gsl_sf_beta")

(defop 'floor 1 "floor" :type 'int)
(defop 'ceil 1 "ceil" :type 'int)
(defop '= 2 "EQ" :type 'int :c-define "OP_EQ")
(defop '< 2 "LESS" :type 'int :c-define "OP_LESS")
(defop '<i 2 "LESS" :type 'int :arg-type 'int :c-define "OP_LESS_INT")
(defop '<= 2 "LEQ" :type 'int :c-define "OP_LEQ")
(defop 'not 1 "NOT" :type 'int :arg-type 'int)

(defop 'print 1 "PRINT_FLOAT" :type 'int :pure nil)
(defop 'newline 0 "NEWLINE" :type 'int :pure nil)

(defop 'start-debug-tuple 1 "START_DEBUG_TUPLE" :type 'int :arg-type 'int :pure nil)
(defop 'set-debug-tuple-data 2 "SET_DEBUG_TUPLE_DATA" :type 'int
       :arg-types '(int float) :pure nil)

(defop 'orig-val 4 "ORIG_VAL" :interpreter-c-name "ORIG_VAL_INTERPRETER" :type 'tuple
       :arg-types '(float float image float) :foldable nil)
(defop 'red 1 "RED_FLOAT" :arg-type 'color :foldable nil)
(defop 'green 1 "GREEN_FLOAT" :arg-type 'color :foldable nil)
(defop 'blue 1 "BLUE_FLOAT" :arg-type 'color :foldable nil)
(defop 'alpha 1 "ALPHA_FLOAT" :arg-type 'color :foldable nil)

(defop 'tuple-nth 2 "TUPLE_NTH" :type 'float :arg-types '(tuple int) :foldable nil)

(defop 'complex 2 "COMPLEX" :type 'complex)
(defop 'c-real 1 "crealf" :arg-type 'complex)
(defop 'c-imag 1 "cimagf" :arg-type 'complex)
(defop 'c-sqrt 1 "csqrtf" :type 'complex :arg-type 'complex)
(defop 'c-sin 1 "csinf" :type 'complex :arg-type 'complex)
(defop 'c-cos 1 "ccosf" :type 'complex :arg-type 'complex)
(defop 'c-tan 1 "ctanf" :type 'complex :arg-type 'complex)
(defop 'c-asin 1 "casinf" :type 'complex :arg-type 'complex)
(defop 'c-acos 1 "cacosf" :type 'complex :arg-type 'complex)
(defop 'c-atan 1 "catanf" :type 'complex :arg-type 'complex)
(defop 'c-pow 2 "cpowf" :type 'complex :arg-type 'complex)
(defop 'c-exp 1 "cexpf" :type 'complex :arg-type 'complex)
(defop 'c-log 1 "clogf" :type 'complex :arg-type 'complex)
(defop 'c-arg 1 "cargf" :arg-type 'complex)
(defop 'c-sinh 1 "csinhf" :type 'complex :arg-type 'complex)
(defop 'c-cosh 1 "ccoshf" :type 'complex :arg-type 'complex)
(defop 'c-tanh 1 "ctanhf" :type 'complex :arg-type 'complex)
(defop 'c-asinh 1 "casinhf" :type 'complex :arg-type 'complex)
(defop 'c-acosh 1 "cacoshf" :type 'complex :arg-type 'complex)
(defop 'c-atanh 1 "catanhf" :type 'complex :arg-type 'complex)
(defop 'c-gamma 1 "cgamma" :type 'complex :arg-type 'complex)

(defop 'ell-int-k-comp 1 "ELL_INT_K_COMP")
(defop 'ell-int-e-comp 1 "ELL_INT_E_COMP")

(defop 'ell-int-f 2 "ELL_INT_F")
(defop 'ell-int-e 2 "ELL_INT_E")
(defop 'ell-int-p 3 "ELL_INT_P")
(defop 'ell-int-d 3 "ELL_INT_D")

(defop 'ell-int-rc 2 "ELL_INT_RC")
(defop 'ell-int-rd 3 "ELL_INT_RD")
(defop 'ell-int-rf 3 "ELL_INT_RF")
(defop 'ell-int-rj 4 "ELL_INT_RJ")

(defop 'ell-jac 2 "ELL_JAC" :type 'v3)

(defop 'make-m2x2 4 "MAKE_M2X2" :type 'm2x2)
(defop 'make-m3x3 9 "MAKE_M3X3" :type 'gsl-matrix :pure nil)
(defop 'free-matrix 1 "FREE_MATRIX" :type 'int :arg-type 'gsl-matrix :pure nil)

(defop 'make-v2 2 "MAKE_V2" :type 'v2)
(defop 'make-v3 3 "MAKE_V3" :type 'v3)
(defop 'v2-nth 2 "VECTOR_NTH" :arg-types '(int v2) :foldable nil)
(defop 'v3-nth 2 "VECTOR_NTH" :arg-types '(int v3) :foldable nil)

(defop 'solve-linear-2 2 "SOLVE_LINEAR_2" :type 'v2 :arg-types '(m2x2 v2) :pure nil)
(defop 'solve-linear-3 2 "SOLVE_LINEAR_3" :type 'v3 :arg-types '(gsl-matrix v3) :pure nil)

(defop 'solve-poly-2 3 "SOLVE_POLY_2" :type 'v2 :pure nil)
(defop 'solve-poly-3 4 "SOLVE_POLY_3" :type 'v3 :pure nil)

(defop 'noise 3 "noise")
(defop 'rand 2 "RAND" :pure nil)

(defop 'userval-int 1 "USERVAL_INT_ACCESS" :type 'int :arg-type 'int :foldable nil)
(defop 'userval-float 1 "USERVAL_FLOAT_ACCESS" :type 'float :arg-type 'int :foldable nil)
(defop 'userval-bool 1 "USERVAL_BOOL_ACCESS" :type 'int :arg-type 'int :foldable nil)
(defop 'userval-curve 2 "USERVAL_CURVE_ACCESS" :type 'float :arg-types '(int float) :foldable nil)
(defop 'userval-color 1 "USERVAL_COLOR_ACCESS" :type 'color :arg-type 'int :foldable nil)
(defop 'userval-gradient 2 "USERVAL_GRADIENT_ACCESS" :type 'color :arg-types '(int float) :foldable nil)
(defop 'userval-image 1 "USERVAL_IMAGE_ACCESS" :type 'image :arg-type 'int :foldable nil)

(defop 'output-tuple 1 "OUTPUT_TUPLE" :interpreter-c-name "OUTPUT_TUPLE_INTERPRETER"
       :type 'int :arg-type 'tuple :pure nil)

(defun max-type (types)
  (cond ((null types)
	 (error "cannot determine max type of empty list"))
	((null (cdr types))
	 (car types))
	(t
	 (let ((rest-max (max-type (cdr types))))
	   (cond ((eq (car types) *complex-type*)
		  *complex-type*)
		 ((eq (car types) *int-type*)
		  rest-max)
		 (t
		  (assert (eq (car types) *float-type*))
		  (if (eq rest-max *complex-type*)
		      *complex-type*
		    *float-type*)))))))

(defun make-op-defines ()
  (apply #'string-concat
	 (mapcar #'(lambda (op index)
		     (format nil "#define ~A ~A~%" (op-c-define op) index))
		 (reverse *operators*) (integers-upto (length *operators*)))))

(defun make-init-ops ()
  (apply #'string-concat
	 (mapcar #'(lambda (op)
		     (format nil "    init_op(~A, \"~A\", ~A, TYPE_PROP_~A, ~A, ~:[0~;1~], ~:[0~;1~]~{, ~A~});~%"
			     (op-c-define op) (op-c-name op) (op-arity op) (ucs (op-type-prop op))
			     (rt-type-c-define (op-type op)) (op-pure op) (op-foldable op)
			     (if (eq (op-type-prop op) 'const)
				 (mapcar #'rt-type-c-define (op-arg-types op))
				 '())))
		 (reverse *operators*))))

(defun max-type-prop-types (type-prop)
  (ecase type-prop
    (max *max-types*)
    (max-float *max-float-types*)))

(defun make-rhs-op-switch (const-handler max-handler only-foldables)
  (apply #'string-concat
	 (mapcar #'(lambda (op)
		     (labels ((switch-args (arg-types)
				(if (= (length arg-types) (op-arity op))
				    (format nil "~A~%" (funcall max-handler op arg-types))
				    (format nil "switch (primary_type(&rhs->v.op.args[~A])) {~%~Adefault : assert(0); break;~%}~%"
					    (length arg-types)
					    (apply #'string-concat
						   (mapcar #'(lambda (type)
							       (format nil "case ~A :~%~A"
								       (rt-type-c-define type)
								       (switch-args (append arg-types (list type)))))
							   (max-type-prop-types (op-type-prop op))))))))
		       (if (or (not only-foldables) (op-foldable op))
			   (if (eq (op-type-prop op) 'const)
			       (format nil "case ~A :~%~A~%"
				       (op-c-define op)
				       (funcall const-handler op))
			       (format nil "case ~A :~%~A"
				       (op-c-define op)
				       (switch-args '())))
			   "")))
		 (reverse *operators*))))

(defun make-op-folders ()
  (make-rhs-op-switch #'(lambda (op)
			  (format nil "return make_~A_const_primary(~A(~{OP_CONST_~A_VAL(~A)~^, ~}));"
				  (dcs (rt-type-name (op-type op))) (op-c-name op)
				  (mappend #'(lambda (i)
					       (list (ucs (rt-type-name (nth i (op-arg-types op)))) i))
					   (integers-upto (op-arity op)))))
		      #'(lambda (op arg-types)
			  (let ((max-type (max-type arg-types)))
			    (format nil "return make_~A_const_primary(~A(~{(~A)rhs->v.op.args[~A].v.constant.~A_value~^, ~}));"
				    (dcs (rt-type-name max-type)) (op-c-name op)
				    (mappend #'(lambda (i arg-type)
						 (list (rt-type-c-type max-type) i (dcs (rt-type-name arg-type))))
					     (integers-upto (op-arity op)) arg-types))))
		      t))

(defun make-builtin-getter ()
  (make-rhs-op-switch #'(lambda (op)
			  (format nil "return builtin_~A;" (string-downcase (op-c-define op))))
		      #'(lambda (op arg-types)
			  (let ((max-type (max-type arg-types)))
			    (format nil "return builtin_~A_~A;" (string-downcase (op-c-define op)) (dcs (rt-type-name max-type)))))
		      nil))

(defun interpret-c-format-string (format args)
  (labels ((interpret-format (char arg)
	     (ecase char
	       (#\d (format nil "fprintf(out, \"%d\", ~A);" arg))
	       (#\p (format nil "fprintf(out, \"%p\", ~A);" arg))
	       (#\f (format nil "{ gchar buf[G_ASCII_DTOSTR_BUF_SIZE]; g_ascii_dtostr(buf, sizeof(buf), ~A); fputs(buf, out); }"
			    arg)))))
    (if (> (length format) 0)
	(let ((pos (position #\% format)))
	  (if (null pos)
	      (format nil "fputs(\"~A\", out);" format)
	      (format nil "fputs(\"~A\", out); ~A ~A"
		      (subseq format 0 pos)
		      (interpret-format (aref format (1+ pos)) (car args))
		      (interpret-c-format-string (subseq format (+ pos 2)) (cdr args)))))
	"")))

(defun make-types-file ()
  (with-open-file (out "compiler_types.h" :direction :output :if-exists :supersede)
    (format out "~{#define ~A ~A~%~}"
	    (mappend #'(lambda (type index)
			 (list (rt-type-c-define type) index))
		     *types* (integers-upto (length *types*))))
    (format out "~%#define MAX_TYPE ~A~%~%" (rt-type-c-define (car (last *types*))))
    (labels ((value-decls (name element-namer)
	       (format out "#define ~A ~{~A ~A;~^ ~}~%~%"
		       name
		       (mappend #'(lambda (type)
				    (let ((c-type (rt-type-c-type type)))
				      (if (null c-type)
					  '()
					  (list c-type (funcall element-namer type)))))
				*types*))))
      (value-decls "RUNTIME_VALUE_DECL" #'(lambda (type) (format nil "~A_value" (dcs (rt-type-name type))))))
    (format out "#define MAKE_TYPE_C_TYPE_NAME static char* \\~%type_c_type_name (int type) \\~%{ \\~%switch (type) \\~%{ \\~%~{case ~A : return ~A; \\~%~}default : assert(0); return 0; \\~%} \\~%}~%~%"
	    (mappend #'(lambda (type)
			 (let ((c-type (rt-type-c-type type)))
			   (list (rt-type-c-define type)
				 (if (null c-type)
				     "0"
				     (format nil "\"~A\"" c-type)))))
		     *types*))
    (dolist (type *types*)
      (unless (null (rt-type-c-type type))
	(format out "#define BUILTIN_~A_ARG(i) (g_array_index(invocation->mathmap->interpreter_values, runtime_value_t, arg_indexes[(i)]).~A_value)~%"
		(ucs (rt-type-name type)) (dcs (rt-type-name type)))))
    (format out "#define MAKE_CONST_PRIMARY_FUNCS \\~%~{MAKE_CONST_PRIMARY(~A, ~A, ~A)~^ \\~%~}~%~%"
	    (mappend #'(lambda (type)
			 (if (null (rt-type-c-type type))
			     nil
			     (list (dcs (rt-type-name type)) (rt-type-c-type type) (rt-type-c-define type))))
		     *types*))
    (format out "#define MAKE_CONST_COMPARATOR \\~%~{case ~A : return ~A;~^ \\~%~}~%~%"
	    (mappend #'(lambda (type)
			 (if (null (rt-type-c-type type))
			     nil
			   (list (rt-type-c-define type)
				 (let ((dcsname (dcs (rt-type-name type))))
				   (if (null (rt-type-comparer type))
				       (format nil "~{prim1->v.constant.~A_value~A == prim2->v.constant.~2:*~A_value~A~^ && ~}"
					       (if (null (rt-type-elements type))
						   (list dcsname "")
						   (mappend #'(lambda (element)
								(list dcsname (string-concat "." element)))
							    (rt-type-elements type))))
				       (format nil "~A(prim1->v.constant.~A_value, prim2->v.constant.~:*~A_value);"
					       (rt-type-comparer type) dcsname))))))
		     *types*))
    (labels ((printer (name spec-accessor)
	       (format out "#define ~A \\~%~{case ~A : ~A break;~^ \\~%~}~%~%"
		       name
		       (mappend #'(lambda (type)
				    (list (rt-type-c-define type)
					  (if (null (rt-type-printer type))
					      (let* ((print-info (rt-type-print-info type))
						     (args (mapcar #'(lambda (arg-spec)
								       (format nil arg-spec
									       (format nil "primary->v.constant.~A_value"
										       (dcs (rt-type-name type)))))
								   (car (last print-info)))))
						(interpret-c-format-string (funcall spec-accessor print-info) args))
					      (format nil "~A(primary->v.constant.~A_value);"
						      (rt-type-printer type)
						      (dcs (rt-type-name type))))))
				*types*))))
      (printer "TYPE_DEBUG_PRINTER" #'first)
      (printer "TYPE_C_PRINTER" #'second))))

(defun print-op-builtins (op)
  (labels ((function-header (name)
	     (format nil "static void~%builtin_~A (mathmap_invocation_t *invocation, int *arg_indexes)"
		     name))
	   (print-function (name op type arg-types)
	     (format t "~A~%{~%BUILTIN_~A_ARG(0) = ~A(~{BUILTIN_~A_ARG(~A)~^, ~});~%}~%"
		     (function-header name)
		     (ucs (rt-type-name type))
		     (op-interpreter-c-name op)
		     (mappend #'(lambda (i)
				  (list (ucs (rt-type-name (nth i arg-types)))
					(1+ i)))
			      (integers-upto (op-arity op))))))
  (if (eq (op-type-prop op) 'const)
      (print-function (string-downcase (op-c-define op)) op (op-type op) (op-arg-types op))
      (dolist (type (max-type-prop-types (op-type-prop op)))
	(print-function (format nil "~A_~A" (string-downcase (op-c-define op)) (dcs (rt-type-name type)))
			op type (map-times (op-arity op) #'(lambda (i) type)))))))

(defun make-ops-file ()
  (with-open-file (out "opdefs.h" :direction :output :if-exists :supersede)
    (let ((*standard-output* out))
      (format t "~A~%#define NUM_OPS ~A~%~%" (make-op-defines) (length *operators*))
      (format t "static void~%init_ops (void)~%{~%~A}~%~%" (make-init-ops))
      (format t "static primary_t~%fold_rhs (rhs_t *rhs)~%{~%assert(rhs_is_foldable(rhs));~%switch(rhs->v.op.op->index)~%{~%~Adefault : assert(0);~%}~%}~%" (make-op-folders))
      (dolist (op (reverse *operators*))
	(print-op-builtins op))
      (format t "static builtin_func_t~%get_builtin (rhs_t *rhs)~%{~%switch (rhs->v.op.op->index)~%{~%~Adefault : assert(0);~%}~%}~%" (make-builtin-getter)))))
