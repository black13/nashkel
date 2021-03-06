;;  -*-  indent-tabs-mode:nil; coding: utf-8 -*-
;;  Copyright (C) 2014
;;      "Mu Lei" known as "NalaGinrut" <NalaGinrut@gmail.com>
;;  Nashkel is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.

;;  Nashkel is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.

;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; ====================================================================
;; The meta tree stuffs, users shouldn't use this module directly.
;; Other trees are based on this module.

(define-module (nashkel meta-tree)
  #:use-module (nashkel utils)
  #:use-module (nashkel stack)
  #:use-module (nashkel queue)
  #:use-module ((rnrs) #:select (define-record-type record-rtd record-type-parent))
  #:use-module (ice-9 control)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:export (tree-node
            tree-node-left tree-node-left-set!
            tree-node-right tree-node-right-set!
            tree-left-set! tree-left
            tree-right-set! tree-right
            tree-parent-set! tree-parent
            is-left-grand-child?
            tree-grand-parent
            is-left-child?
            is-right-child?
            tree-size
            make-tree-node
            tree-node?
            tree-node-parent tree-node-parent-set!
            tree-node-children tree-node-children-set!
            head-node
            make-head-node
            head-node?
            head-node-type head-node-type-set!
            head-node-count head-node-count-set!
            head-node-tree head-node-tree-set!
            root? non-root?
            tree-empty?
            tree-root
            tree-root-set!            
            make-tree
            tree-add-node!
            tree-remove-node!
            subtree-size
            no-children?
            count+1!
            count-1!
            ;; BST generic operations
            meta-tree-BST-select
            meta-tree-BST-rank
            meta-tree-BST-successor
            meta-tree-BST-predecessor
            meta-tree-BST-floor
            meta-tree-BST-ceiling
            meta-tree-BST-find
            meta-tree-BST-add!
            leaf? non-leaf?
            make-meta-tree-walker
            pre-order-traverse
            in-order-traverse
            post-order-traverse
            make-bfs-walker
            node-fold))

;; CONVENTIONs:
;; * leaf node is #f.
;; * leaf is different from any specific node, so if a node is a valid specific node, it's not a leaf.
;; * PRED returns: =0 hit, >0 logical greater, <0 logical lesser.
;;   these are the work of users who defined pred. 
;; * children never been '(), the initial value should be '(#f #f).
;; * tree-meta should be the first direct parent of any specific tree node.

(define-record-type tree-node
  (fields
   (mutable parent)
   (mutable children)))

(define-syntax-rule (tree-meta tree) (record-parent-ref tree 0))

;; only for binary tree
;; --------------------------------------------
(define-syntax-rule (valid-children? c)
  (and (list? c) (= (length c) 2)))

;; ---------------tree-node-* functions----------------------------------
;; These functions are used by tree-node type.
(define (children-setter! index node new)
  (let* ((children (tree-node-children node))
         (cl (if (zero? index)
                 (list new (cadr children))
                 (list (car children) new))))
    (tree-node-children-set! node cl)))
    
(define-syntax-rule (tree-node-left-set! node new) (children-setter! 0 node new))
(define-syntax-rule (tree-node-right-set! node new) (children-setter! 1 node new))
;; -----------------------------------------------------------------------

;; ---------------tree-* functions----------------------------------------
;; These functions are used by specific tree implementation, e.g. rbt
(define (tree-left-set! t new)
  (if (non-leaf? t)
      (tree-node-left-set! t new)
      (error tree-left-set! "Shouldn't be leaf!" t)))

(define (tree-right-set! t new)
  (if (non-leaf? t)
      (tree-node-right-set! t new)
      (error tree-right-set! "Shouldn't be leaf!" t)))

(define (tree-parent-set! t new)
  (if (non-leaf? t)
      (tree-node-parent-set! t new)
      (error tree-parent-set! "Shouldn't be leaf!" t)))

(define (tree-left t)
  (if (non-leaf? t)
      (car (tree-node-children t))
      (error tree-left "Shouldn't be leaf!" t)))

(define (tree-right t)
  (if (non-leaf? t)
      (cadr (tree-node-children t))
      (error tree-right "Shouldn't be leaf!" t)))

(define (tree-parent t)
  (if (non-leaf? t)
      (tree-node-parent t)
      (error tree-parent "Shouldn't be leaf!" t)))
;; ------------------------------------------------------------------------

;; tree node helper functions
;; NOTE: Don't do any check since they're low-level.
(define-syntax-rule (is-left-child? c)
  (eq? c (tree-left (tree-parent c))))

(define-syntax-rule (is-right-child? c)
  (eq? c (tree-right (tree-parent c))))

;; TODO: any check here?
(define-syntax-rule (tree-grand-parent n)
  (tree-parent (tree-parent n)))
;; -----------------------------------------------------------------------

;; ---------------------------------------------

(define-record-type head-node
  (fields
   type
   (mutable count)
   (mutable tree)))

;; NOTE: leaf node has no children 
(define (leaf? node) (not node))
(define (non-leaf? node) node)

;; root pred
(define-syntax-rule (root? node) (not (tree-parent node)))
(define-syntax-rule (non-root? node) node)
(define tree-root head-node-tree)
(define tree-root-set! head-node-tree-set!)

(define (tree-empty? head)
  (and (zero? (head-node-count head))
       (root? (head-node-tree head))))

(define-syntax-rule (make-tree tree-maker type . args)
  (let* ((tree (apply tree-maker args))
         (head (make-head-node type 0 tree)))
    head))

(define-syntax-rule (count+1! head)
  (head-node-count-set! head (1+ (head-node-count head))))

(define-syntax-rule (count-1! head)
  (head-node-count-set! head (1- (head-node-count head))))

(define-syntax-rule (tree-size head) (head-node-count head))

;; specified tree adder implemention should use functions below:
;; ------------------------------------------------------------
(define-syntax-rule (tree-add-node! head adder! node)
  (begin
    (adder! (head-node-tree head node))
    (count+1! head)))

(define-syntax-rule (tree-remove-node! head remover! node)
  (begin
    (remover! (head-node-tree head) node)
    (count-1! head)))
;; ------------------------------------------------------------

;; -------------------traverse stuffs--------------------------
(define-syntax-rule (pre-order-traverse tree valid? operate err)
  (cond
   ((leaf? tree) #t) ; traverse over
   ((valid? tree)
    (operate tree) ; pre operate
    (for-each 
     (lambda (c) (pre-order-traverse c valid? operate))
     (tree-node-children tree)))
   (else (err pre-order-traverse "Shouldn't be here!" tree))))

(define-syntax-rule (post-order-traverse tree valid? operate err)
  (cond
   ((leaf? tree) #t) ; traverse over
   ((valid? tree)
    (for-each 
     (lambda (c) (pre-order-traverse c valid? operate))
     (tree-node-children tree))
    (operate tree)) ; post operate
    (else (err pre-order-traverse "Shouldn't be here!" tree))))

;; NOTE: this in-order traverse only for binary tree
;; Iterative in order traverse.
;; 1. Create an empty stack S.
;; 2. Initialize current node as root
;; 3. Push the current node to S and set current = current->left until current is NULL
;; 4. If current is NULL and stack is not empty then 
;;    a. Pop the top item from stack.
;;    b. Print the popped item, set current = current->right 
;;    c. Go to step 3.
;; 5. If current is NULL and stack is empty then we are done.
(define (in-order-traverse tree operate err)
  (define stk (new-stack))
  (let lp((t tree))
    (cond
     ((non-leaf? t)
      ;; push all left children as possible
      (stack-push! stk t)
      (lp (tree-left t))) ; left
     ((and (leaf? t) (not (stack-empty? stk))) 
      ;; when current path is end, pop one then loop on its right child
      (let ((x (stack-pop! stk)))
        (operate x) ; center
        (lp (tree-right t)))) ; right
     ((and (leaf? t) (stack-empty? stk)) #t) ; end
     (else (err in-order-traverse "Fatal: Shouldn't be here!" (->list t))))))

(define (in-order-traverse/step tree err)
  (reset
   (define stk (new-stack))
   (let lp((t tree))
     (cond
      ((non-leaf? t)
       ;; push all left children as possible
       (stack-push! stk t)
       (lp (tree-left t))) ; left
      ((and (leaf? t) (not (stack-empty? stk))) 
       ;; when current path is end, pop one then loop on its right child
       (let ((x (stack-pop! stk)))
         (shift k (list k x)) ; center
         (lp (tree-right t)))) ; right
      ((and (leaf? t) (stack-empty? stk)) #t) ; end
      (else (err in-order-traverse "Fatal: Shouldn't be here!" (->list t)))))))

(define-macro (make-meta-tree-walker mode valid? operate err)
  (lambda (head)
    `(,(symbol-append mode '-order-traverse) ,(head-node-tree head) valid? operate err)))

(define-syntax make-bfs-walker 
  (syntax-rules (any all)
    ((any valid? PRED tree err)
     (lambda (head) (bfs-any PRED valid? (head-node-tree head) err)))
    ((all valid? operate tree err)
     (lambda (head) (bfs-for-each operate valid? (head-node-tree head) err)))))

(define (bfs-any PRED key valid? tree err)
  (cond
   ((not (valid? tree))
    (err bfs-any "Invalid tree!" tree))
   ((not (leaf? tree))
    (let lp((children (tree-node-children tree)))
      (cond
       ((leaf? children) #f)
       ((zero? (PRED tree key)) tree)
       (else (car (map (cut bfs-any PRED key valid? <> err) children))))))))

(define (bfs-for-each operate valid? tree err)
  (cond
   ((not (valid? tree))
    (err bfs-for-each "Invalid tree!" tree))
   ((not (leaf? tree))
    (let lp((children (tree-node-children tree)))
      (operate tree)
      (for-each (cut bfs-for-each operate valid? <> err) children)))))

;; bfs generic stuff
(define (bfs-for-each/step valid? tree err)
  (reset
   (let lp((node tree))
     (cond
      ((not (valid? node))
       (err bfs-for-each/step "Invalid tree!" node))
      ((not (leaf? node))
       (let ((children (tree-node-children node)))
         (shift k (list k node))
         (for-each (cut lp <>) children)))))))

;; Generic tree walker
;; ---------------------------------------------------------------
;; chew/spit
;; (define next (chew (proc-who-returns-k-val-pairs ...)))
(define (chew kvp)
  (let ((k0 kvp))
    (lambda ()
      (match k0
        (((? procedure? k) val)
         (set! k0 (k))
         val)
        (else '*end-continuation*)))))
;; Although (next) is clearly, (spit next) is better to understand
;; and more natural.
;; (spit next)
(define-syntax-rule (spit next) (next))

;; e.g 
;; (let ((next (chew (bfs-for-each/step meta valid? tree err))))
;;  (tree-for-each operate valid? next err))
(define (tree-for-each operate valid? next err)
  (let lp((n (spit next)))
    (cond
     ((valid? n)
      (operate n)
      (lp (spit next)))
     ((eq? n '*end-continuation*))
     (else (err tree-for-each "Invalid node!" n)))))
;; ----------------------------------------------------------------

(define (subtree-size tree valid? err)
  (let ((next (chew (bfs-for-each/step tree valid? err))))
    (let lp((n (spit next)) (cnt 0))
      (cond
       ((valid? n)
        (lp (spit next) (1+ cnt)))
       ((eq? n '*end-continuation*) cnt)
       (else (err subtree-size "Invalid node!" n))))))

(define (no-children? tree)
  (and (leaf? (tree-left tree))
       (leaf? (tree-right tree))))

;; NOTE: return a subtree containing rank n.
(define* (meta-tree-BST-select tree n err #:key (PRED identity))
  (if (leaf? tree)
      #f ; no result
      (let lp((t tree) (n n))
        (cond
         ((leaf? t) #f) ; no result
         (else
          (let ((i (subtree-size (tree-left t) PRED err)))
            (cond
             ((> i n) (lp (tree-left t) n))
             ((< i n) (lp (tree-right t) (- i n 1)))
             (else t))))))))

;; return the number of nodes whose key is lesser than given key.
(define (meta-tree-BST-rank tree PRED key err)
  (let ((next (chew (in-order-traverse/step tree err))))
    (let lp((n (spit next)) (cnt 0))
      (match (PRED n key)
        ((? (cut eq? <> '*end-continuation*)) cnt)
        ((? negative?) (lp (spit next) (1+ cnt))) ; lesser than key, suitable node.
        ;; force to end, since it's BST, so there's no suitable node after this node.
        ((? zero?) (lp '*end-continuation* (1+ cnt))) 
        (else (err meta-tree-BST-rank "Fatal: Shouldn't be here!" (->list n)))))))

;; The successor s the smallest item in t that is strictly greater than X.
;;
;; * If node x has a non-empty right subtree, then x's successor is the minimum 
;;   in its right subtree.
;; * If node x has an empty right subtree, then y is the lowest ancestor of x 
;;   whose left child is also an ancestor of x.   To see this, consider these facts:
;;   ** If y is the successor of x then x is the predecessor of y, so x is the maximum 
;;      in y's left subtree (flip the reasoning of your answer to the last question).
;;   ** Moving from x to the left up the tree (up through right children) reaches nodes
;;      with smaller keys, which must also be in this left subtree.
;;
;;  N is the set of all nodes in certain tree. R is the set of nodes who is larger than X.
;;  Function 'min(T)' defined as getting the minimum node of tree T.
;;  Assuming Y > X, then min(R) equal to Z. (1)
;;  Assuming PP > P > X, then min(R) equal to P.
;;  
;;  (1)  [ X ]         (2)    [ P ]                    [ PP ]
;;        / \                  / \      ....            / \
;;      ... [ Y ]          [ X ] ...    --->     ==> ...  [ P ]<==     
;;           / \            / \                            / \  
;;     ==>[ Z ] ...       ... ...                      [ X ] ...
(define (meta-tree-BST-successor tree valid? err)
  ;; NOTE: Although root is defined as #f here, please don't rely on
  ;;       it! Use 'false-to-find?' to return #f if no sucessor.
  (define-syntax-rule (false-to-find? x) (or x))
  (when (not (valid? tree))
    (err meta-tree-BST-successor "Invalid tree!" (->list tree)))
  (cond
   ((non-leaf? (tree-right tree)) ; Case (1)
    ;; get min in right subtree
    (meta-tree-BST-floor (tree-right tree) valid? err))
   (else
    (let lp((t tree))
      (cond
       ((and (non-root? t) (is-left-child? t)) ; t is left child
        ;; trace the upper level
        (lp (tree-parent t)))
       (else
        ;; NOTE: What about p is root node?!
        ;;       There's only one situation p can be root, that is tree is
        ;;       the largest node. Usually, we return #f for this. 
        ;; Case (2):
        (false-to-find? (tree-parent t))))))))

;; Predecessor is the largest item in t that is strictly smaller than X.
;;
;; * The reversed principle to successor.
;;  (1)  [ X ]         (2)    [ P ]                    [ PP ]
;;        / \                  / \        ....          / \
;;    [ Y ] ...             ...  [ X ]    --->   ==>[ P ] ...     
;;     / \                        / \                / \  
;;   ... [ Z ]<==               ... ...            ... [ X ]
(define (meta-tree-BST-predecessor tree valid? err)
  (define-syntax-rule (false-to-find x)
    (not x))
  (when (not (valid? tree))
    (err meta-tree-BST-predecessor "Invalid tree!" (->list tree)))
  (cond
   ((non-leaf? (tree-left tree))
    ;; get max in left subtree
    (meta-tree-BST-ceiling (tree-left tree) valid? err))
   (else
    (let ((parent (tree-parent tree)))
      (let lp((t tree) (p parent))
        (cond
         ((and (valid? p) ; not root and valid
               (is-right-child? t)) ; t is a right child
          ;; trace the upper level
          (lp p (tree-parent p)))
         (else (or (false-to-find p) p))))))))

;; floor is the same with min
(define (meta-tree-BST-floor tree valid? err)
  (when (not (valid? tree))
    (err meta-tree-BST-floor "Invalid tree!" (->list tree)))
  (if (non-leaf? (tree-left tree)) 
      (meta-tree-BST-floor (tree-left tree) valid? err) ; next is not leaf, continue
      tree)) ; next is leaf, return current node as final result

;; ceiling is the same with max
(define (meta-tree-BST-ceiling tree valid? err)
  (when (not (valid? tree))
    (err meta-tree-BST-ceiling "Invalid tree!" (->list tree)))
  (if (non-leaf? (tree-right tree)) 
      (meta-tree-BST-ceiling (tree-right tree) valid? err) ; next is not leaf, continue
      tree)) ; next is leaf, return current node as final result

(define (meta-tree-BST-find tree key valid? operate next< next> PRED err)
  (define next
    (cond
     ((not (valid? tree)) (err meta-tree-BST-find "Invalid tree!" tree))
     ;; encounter leaf node here, means "can't find it any more".
     ((leaf? tree) #f)
     (else
      (match (PRED tree key)
        ((? zero?) #t) ; find it
        ((? positive?) (next> tree))
        ((? negative?) (next< tree))
        (else (err meta-tree-BST-find "Shouldn't be here!" tree))))))
  (cond
   ((valid? next) ; haven't found, checkout the next
    (meta-tree-BST-find next key valid? operate next< next> PRED err))
   ((eq? next #t) ; found it, do the specified operation
    (operate tree))
   (else #f))) ; can't find it

(define (meta-tree-BST-add! tree key valid? adder! PRED overwrite! err)
  (when (not (valid? tree))
    (err meta-tree-BST-add! "Invalid tree!" tree))
  (let ((p (tree-parent tree))
        (left (tree-left tree))
        (right (tree-right tree)))
    (match (PRED tree key)
      ((? zero?) 
       ;; find it, if overwritable, it, or return #f
       (if overwrite! (begin (overwrite! tree) '*overwrited*) '*occupied*))
      ((? positive?) ; new key greater than current key, go next>
       (if (non-leaf? right)
           ;; has right child, continue to go right
           (meta-tree-BST-add! right key valid? adder! PRED overwrite! err)
           ;; right is leaf, add to right side
           (adder! tree)))
      ((? negative?) ; new key lesser than current key, go left 
       (if(non-leaf? left)
          ;; has left child, continue to go left
          (meta-tree-BST-add! left key valid? adder! PRED overwrite! err)
          ;; left is leaf, add to right side
          (adder! tree)))
      (else (err meta-tree-BST-add! "Fatal0: Shouldn't be here!" (->list tree))))))

(define (node-fold init proc node)
  (cond
   ((leaf? node) init)
   (else
    (if (tree-left node)
        (let ((accum (node-fold init proc (tree-left node))))
          (if (tree-right node)
              (node-fold (proc accum node) proc (tree-right node))
              (proc accum node)))
        (if (tree-right node)
            (node-fold (proc init node) proc (tree-right node))
            (proc init node))))))
