(* monae: Monadic equational reasoning in Coq                                 *)
(* Copyright (C) 2020 monae authors, license: LGPL-2.1-or-later               *)
Ltac typeof X := type of X.
Require Import ssrmatching.
From mathcomp Require Import all_ssreflect.
Require Import imonae_lib.
From HB Require Import structures.
Require Import ihierarchy.

(******************************************************************************)
(*  Properties and examples of functors, natural transformations, and monads  *)
(*                                                                            *)
(*            liftM2 h m1 m2 == as in Haskell                                 *)
(*      examples of functors : squaring, curry_F, uncurry_F, exponential_F    *)
(*                       NId == identity natural transformation               *)
(*                        \v == vertical composition of natural               *)
(*                              transformations                               *)
(*                        \h == horizontal composition of natural             *)
(*                              transformations                               *)
(*                    F ## n == application of the functor F to the natural   *)
(*                              transformation n                              *)
(*                      fork == the natural transformation fun A a => (a, a)  *)
(*                    F -| G == adjoint functors                              *)
(*   Module monad_of_adjoint == derivation of a monad from an adjunction      *)
(* Section composite_adjoint == composition of adjunctions                    *)
(*                                                                            *)
(*            E.-operation M == sigma operation for a monad M given a         *)
(*                              functor E                                     *)
(*           algebraicity op == the operation op is algebraic                 *)
(*          E .-aoperation M == algebraic E.-operation M                      *)
(*                                                                            *)
(*                  mpair xy := xy.1 >>= (fun u => xy.2 >>=                   *)
(*                                (fun v => (Ret (u, v)))                     *)
(*             commute m n f := (m >>= n >>= f) = (n >>= m >>= f)             *)
(*                              (ref: definition 4.2, mu2019tr3)              *)
(*                  rep n mx == mx >> mx >> ... >> mx, n times                *)
(*                                                                            *)
(******************************************************************************)

Reserved Notation "f ^`2" (format "f ^`2", at level 3).
Reserved Notation "F ## g" (at level 11).
Reserved Notation "E .-operation M" (at level 2, format "E  .-operation  M").
Reserved Notation "E .-aoperation M" (at level 2, format "E  .-aoperation  M").

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope monae_scope.

Lemma bind_if (M : monad) (A B : UU0) (b : bool) (m : M A) (f g : A -> M B) :
  m >>= (fun x => if b then f x else g x) = if b then m >>= f else m >>= g.
Proof. by case: ifPn. Qed.

Lemma if_bind (M : monad) (A B : UU0) (b : bool) (m n : M A) (f : A -> M B) :
  (if b then m else n) >>= f = (if b then m >>= f else n >>= f).
Proof. by case: ifPn. Qed.

Local Open Scope mprog.
Lemma mfoldl_rev {M : monad} (T R : UU0) (f : R -> T -> R) (z : R) (s : seq T -> M (seq T)) :
  foldl f z (o) (rev (o) s) = foldr (fun x => f^~ x) z (o) s.
Proof.
apply funext => x; rewrite !fcompE 3!fmapE !bindA.
bind_ext => ?; by rewrite bindretf /= -foldl_rev.
Qed.
Local Close Scope mprog.

Definition liftM2 {M : monad} (A B C : UU0) (h : A -> B -> C) m1 m2 : M C :=
  m1 >>= (fun a => m2 >>= (fun b => Ret (h a b))).

Section liftM2_lemmas.
Variables (M : monad) (A B C : UU0) (h : A -> B -> C).

Lemma liftM2E m1 m2 D (f : C -> M D) : liftM2 h m1 m2 >>= f =
  m1 >>= (fun x => m2 >>= fun y => f (h x y)) :> M _.
Proof.
rewrite /liftM2 bindA; under eq_bind do rewrite bindA.
by bind_ext => s; under eq_bind do rewrite bindretf.
Qed.

Lemma liftM2_ret a b : liftM2 h (Ret a) (Ret b) = Ret (h a b) :> M _.
Proof. by rewrite /liftM2 !bindretf. Qed.

Lemma bind_liftM2_size (f : seq A -> seq B -> seq C)
    (m1 : M (seq A)) (m2 : M (seq B)) n :
  (forall a b, size (f a b) = size a + size b + n) ->
  liftM2 f m1 m2 >>= (fun x => Ret (x, size x)) =
  liftM2 (fun a b => (f a.1 b.1, a.2 + b.2 + n))
          (m1 >>= (fun x => Ret (x, size x)))
          (m2 >>= (fun x => Ret (x, size x))).
Proof.
move=> hf.
rewrite /liftM2 !bindA; bind_ext => x1.
rewrite !bindretf !bindA.
bind_ext=> x2.
by rewrite !bindretf /= hf.
Qed.

End liftM2_lemmas.
Arguments bind_liftM2_size {M A B C} {f} m1 m2 n.

Definition Squaring (A : UU0) := (A * A)%type.
Definition squaring_f (A B : UU0) (f : A -> B) : Squaring A -> Squaring B :=
  fun x => (f x.1, f x.2).
Lemma squaring_f_id : FunctorLaws.id squaring_f.
Proof. by move=> A /=; apply funext => -[x1 x2]. Qed.
Lemma squaring_f_comp : FunctorLaws.comp squaring_f.
Proof. by move=> A B C g h /=; apply funext => -[x1 x2]. Qed.
HB.instance Definition _ :=
  isFunctor.Build Squaring squaring_f_id squaring_f_comp.
Definition squaring : functor := [the functor of Squaring].
Notation "f ^`2" := (squaring # f).
Lemma squaringE (A B : UU0) (f : A -> B) x : (f ^`2) x = (f x.1, f x.2).
Proof. by []. Qed.

Section curry_functor.
Variable X : UU0.
Definition curry_M : UU0 -> UU0 := fun B => (X * B)%type.
Definition curry_f (A B : UU0) (f : A -> B) : curry_M A -> curry_M B :=
  fun x : X * A => (x.1, f x.2).
Lemma curry_f_id : FunctorLaws.id curry_f.
Proof.
by rewrite /FunctorLaws.id => A; rewrite /curry_f; apply funext => -[].
Qed.
Lemma curry_f_comp : FunctorLaws.comp curry_f.
Proof.
by rewrite /FunctorLaws.comp => A B C g h; rewrite /curry_f; apply funext => -[].
Qed.
HB.instance Definition _ :=
  @isFunctor.Build curry_M curry_f curry_f_id curry_f_comp.
Definition curry_F : functor := [the functor of curry_M].
End curry_functor.

Section uncurry_functor.
Definition uncurry_M (X : UU0) : UU0 -> UU0 := fun B => X -> B.
Definition uncurry_f (X A B : UU0) (f : A -> B) : uncurry_M X A -> uncurry_M X B :=
  fun g : X -> A => f \o g.
Lemma uncurry_f_id X : FunctorLaws.id (@uncurry_f X).
Proof.
rewrite /FunctorLaws.id => A; rewrite /uncurry_f; apply funext => ?.
by rewrite compidf.
Qed.
Lemma uncurry_f_comp X : FunctorLaws.comp (@uncurry_f X).
Proof.
rewrite /FunctorLaws.comp => A B C g h; rewrite /uncurry_f; apply funext => ?.
by rewrite compE compA.
Qed.
HB.instance Definition _ X :=
  isFunctor.Build (@uncurry_M X) (uncurry_f_id X) (uncurry_f_comp X).
Definition uncurry_F X : functor := [the functor of @uncurry_M X].
End uncurry_functor.

Section exponential_functor.
Variable A : UU0.
Definition exponential_M (X : UU0) := A -> X.
Definition exponential_f (X Y : UU0) (f : X -> Y) :
  exponential_M X -> exponential_M Y := fun e => f \o e.
Lemma exponential_f_id : FunctorLaws.id exponential_f. Proof. by []. Qed.
Lemma exponential_f_comp : FunctorLaws.comp exponential_f.
Proof. by []. Qed.
HB.instance Definition _ :=
  @isFunctor.Build exponential_M exponential_f exponential_f_id exponential_f_comp.
Definition exponential_F : functor := [the functor of exponential_M].
End exponential_functor.

Lemma fmap_oE (M : functor) (A B C : UU0) (f : A -> B) (g : C -> A) (m : M C) :
  (M # (f \o g)) m = (M # f) ((M # g) m).
Proof. by rewrite functor_o. Qed.

Section id_natural_transformation.
Variables C : functor.
Definition NId := fun A => @id (C A).
Definition natural_id : naturality C C NId. Proof. by []. Qed.
HB.instance Definition _ := isNatural.Build C C NId natural_id.
End id_natural_transformation.
Arguments NId C [A].

Section vertical_composition.
Variables (C D E : functor) (g : D ~> E) (f : C ~> D).

Definition vcomp := locked (fun (A : UU0) => g A \o f A).

Definition natural_vcomp : naturality _ _ vcomp.
Proof.
by move=> A B h; rewrite /vcomp; unlock; rewrite compA natural -compA natural.
Qed.

HB.instance Definition _ := isNatural.Build C E vcomp natural_vcomp.

Definition VComp : C ~> E := [the C ~> E of vcomp].

End vertical_composition.

Notation "f \v g" := [the _ ~> _ of vcomp f g].

Lemma vcompE (F G H : functor) (n1 : F ~> H) (n2 : G ~> F) X :
  (n1 \v n2) X = n1 X \o n2 X.
Proof. by rewrite /= /vcomp /=; unlock. Qed.

Lemma vassoc (F1 F2 G H : functor) (f : F1 ~> F2) (g : G ~> F1) (h : H ~> G) :
  f \v g \v h = f \v (g \v h).
Proof. by apply/nattrans_ext => a /=; rewrite !vcompE. Qed.

Section horizontal_composition.
Variables (F G F' G' : functor) (s : F ~> G) (t : F' ~> G').

Definition hcomp : F' \o F ~~> G' \o G :=
  fun (A : UU0) => @t (G A) \o F' # (@s A).

Lemma natural_hcomp :
  naturality [the functor of F' \o F] [the functor of G' \o G] hcomp.
Proof.
move=> A B h.
rewrite [LHS]compA (natural t) -[LHS]compA -[in RHS]compA.
by congr (_ \o _); rewrite FCompE -2!functor_o (natural s).
Qed.

HB.instance Definition _ := isNatural.Build
  [the functor of F' \o F] [the functor of G' \o G] hcomp natural_hcomp.

Definition HComp : [the functor of F' \o F] ~> [the functor of G' \o G] :=
  [the _ ~> _ of hcomp].

End horizontal_composition.

Notation "f \h g" := (HComp g f).

Section functor_natural_transformation.
Variables (S F G : functor) (nt : F ~> G).

Definition fun_app_nt : S \o F ~~> S \o G :=
  fun (A : UU0) => S # (nt A).

Lemma natural_fun_app_nt :
  naturality [the functor of S \o F] [the functor of S \o G] fun_app_nt.
Proof.
by move=> *; rewrite /fun_app_nt 2!FCompE -2!(@functor_o S) natural.
Qed.

HB.instance Definition _ := isNatural.Build
  [the functor of S \o F] [the functor of S \o G] fun_app_nt natural_fun_app_nt.

Definition functor_app_natural :
    [the functor of S \o F] ~> [the functor of S \o G] :=
  [the _ ~> _ of fun_app_nt].
End functor_natural_transformation.

Arguments functor_app_natural S {_} {_}.
Notation "F '##' g" := (functor_app_natural F g).

Lemma functor_app_naturalE (S F G : functor) (nt : F ~> G) X :
  (S ## nt) X = S # nt X.
Proof. by []. Qed.

Lemma functor_app_natural_hcomp (S F G : functor) (nt : F ~> G) :
  S ## nt = [the _ ~> _ of NId S] \h nt.
Proof. by apply nattrans_ext => a; rewrite functor_app_naturalE. Qed.

Section natural_transformation_example.
Definition fork' : FId ~~> squaring := fun (A : UU0) (a : A) => (a, a).

Lemma fork_natural : naturality _ _ fork'. Proof. by []. Qed.

HB.instance Definition _ := isNatural.Build FId squaring fork' fork_natural.

Definition fork : FId ~> squaring := [the _ ~> _ of fork'].

End natural_transformation_example.

Definition eta_type (f g : functor) := FId ~> [the functor of g \o f].
Definition eps_type (f g : functor) := [the functor of f \o g] ~> FId.
Module TriangularLaws.
Section triangularlaws.
Variables (F G : functor) (eps : eps_type F G) (eta : eta_type F G).
Definition left := forall A, eps (F A) \o (F # eta A) = @id (F A).
Definition right := forall A, (G # eps A) \o eta (G A) = @id (G A).
End triangularlaws.
End TriangularLaws.

Module AdjointFunctor.
Section adjointfunctor.
Variables F G : functor.
Record t := mk {
  eta : eta_type F G ;
  eps : eps_type F G ;
  tri_left : TriangularLaws.left eps eta ;
  tri_right : TriangularLaws.right eps eta}.
End adjointfunctor.
Section lemmas.
Variables (F G : functor) (H : t F G).
Definition hom_iso (A B : UU0) (h : F A -> B) : A -> G B := (G # h) \o @eta _ _ H A.
Definition hom_inv (A B : UU0) (h : A -> G B) : F A -> B := @eps _ _ H B \o (F # h).
End lemmas.
End AdjointFunctor.
Arguments AdjointFunctor.t : clear implicits.

Notation "F -| G" := (AdjointFunctor.t F G).

Section adjoint_example.
Variable (X : UU0).
Definition curry_fun : curry_F X \o uncurry_F X ~~> idfun :=
  fun (A : UU0) (af : X * (X -> A)) => af.2 af.1.
Lemma curry_naturality : naturality [the functor of curry_F X \o uncurry_F X] FId curry_fun.
Proof. by []. Qed.
HB.instance Definition _ := isNatural.Build
  [the functor of curry_F X \o uncurry_F X] FId curry_fun curry_naturality.
Definition curry_eps : eps_type (curry_F X) (uncurry_F X) :=
  [the nattrans [the functor of curry_F X \o uncurry_F X] FId of curry_fun].

Definition curry_fun2 : FId ~~> uncurry_F X \o curry_F X :=
  fun (A : UU0) (a : A) => pair^~ a.
Lemma curry_naturality2 :
  naturality _ [the functor of uncurry_F X \o curry_F X] curry_fun2.
Proof. by []. Qed.
HB.instance Definition _ := isNatural.Build
   _ [the functor of uncurry_F X \o curry_F X] curry_fun2 curry_naturality2.

Definition curry_eta : eta_type (curry_F X) (uncurry_F X) :=
  [the nattrans _ _ of curry_fun2].
Lemma adjoint_currry : curry_F X -| uncurry_F X.
Proof.
apply: (@AdjointFunctor.mk _ _ curry_eta curry_eps).
by move=> A; rewrite /TriangularLaws.left; apply funext => -[].
move=> A; rewrite /TriangularLaws.right /uncurry_F /curry_eps /curry_eta /uncurry_M.
by rewrite /= /uncurry_f /= /comp /=; apply funext => f; apply funext.
Qed.
End adjoint_example.

Module monad_of_adjoint.
Section def.
Variables (F G : functor) (eps : eps_type F G) (eta : eta_type F G).
Definition M := [the functor of G \o F].
Definition mu : M \o M ~~> M := fun A => G # eps (F A).
Definition bind A B (m : M A) (f : A -> M B) : M B := mu ((M # f) m).
End def.
Section prop.
Variables f g : functor.
Hypothesis Had : f -| g.
Let eps : eps_type f g := AdjointFunctor.eps Had.
Let eta : eta_type f g := AdjointFunctor.eta Had.
Section mu_eps_natural.
Notation M := (M f g).
Notation mu := (mu eps).
Lemma muM_natural : naturality _ _ mu.
Proof.
move => A B h.
rewrite (_ : [the functor of M \o M] # h = g # ([the functor of f \o g] # (f # h))) //.
rewrite (_ : _ \o g # ([the functor of f \o g] # (f # h)) =
  g # (@eps (f B) \o ([the functor of f \o g] # (f # h)))); last by rewrite -functor_o.
rewrite -natural FIdE.
rewrite [in LHS]FCompE.
rewrite /mu.
by rewrite -[in LHS](@functor_o g).
Qed.
Lemma epsC A : @eps _ \o @eps _ = @eps _ \o f # (g # (@eps _)) :> ((f \o g) ((f \o g) A) -> A).
Proof. by rewrite -natural. Qed.
Lemma muMA A : @mu A \o @mu (M A) = @mu A \o (M # @mu A).
Proof.
have -> : g # eps (f A) \o g # eps (f (M A)) =
  g # (@eps (f A) \o @eps (f (M A))) by rewrite functor_o.
by rewrite epsC functor_o.
Qed.
End mu_eps_natural.
Lemma bindetaf : BindLaws.left_neutral (bind eps) eta.
Proof.
rewrite /BindLaws.left_neutral => A B a h.
rewrite /bind /mu.
rewrite -(compE ([the functor of g \o f] # h)) (natural eta) -(compE (g # _)) compA.
by rewrite AdjointFunctor.tri_right.
Qed.
Lemma bindmeta : BindLaws.right_neutral (bind eps) eta.
Proof.
rewrite /BindLaws.right_neutral => A m.
rewrite /bind /mu -(compE (g # _)).
by rewrite -functor_o AdjointFunctor.tri_left functor_id.
Qed.
Lemma law3 : BindLaws.associative (bind eps).
Proof.
rewrite /BindLaws.associative => A B C x ab bc.
rewrite /bind.
set N := M f g.  set j := mu eps.
rewrite [X in _ = j C X](_ : _ = (N # (j C)) ((N # (N # bc)) ((N # ab) x))); last first.
  rewrite functor_o.
  rewrite compE.
  congr ((N # j C) _).
  rewrite functor_o.
  by rewrite (compE _ _ x).
move: muMA (muM_natural bc).
rewrite -/N -/j.
move=> muMA.
(*rewrite FCompE.*)
have -> : (N # bc) (j B ((N # ab) x)) = (N # bc \o j B) ((N # ab) x) by [].
move=> ->.
rewrite compE.
rewrite [LHS](_ : _ = (j C \o j (N C)) ((N # (N # bc)) ((N # ab) x))) //.
by rewrite muMA.
Qed.
End prop.
End monad_of_adjoint.

Section composite_adjoint.
Variables (F0 U0 : functor).
Hypothesis H0 : F0 -| U0.
Let eta0 : eta_type F0 U0 := AdjointFunctor.eta H0.
Let eps0 : eps_type F0 U0 := AdjointFunctor.eps H0.
Variables (F U : functor).
Hypothesis H : F -| U.
Let eta : eta_type F U := AdjointFunctor.eta H.
Let eps : eps_type F U := AdjointFunctor.eps H.

Definition uni_fun : FId ~~> (U0 \o U) \o (F \o F0) :=
  fun A : UU0 => U0 # eta (F0 A) \o eta0 A.

Lemma uni_naturality :
  naturality [the functor of idfun] [the functor of (U0 \o U) \o (F \o F0)] uni_fun.
Proof.
move=> A B h; rewrite FIdE.
rewrite -[RHS]compA.
rewrite -(natural (AdjointFunctor.eta H0)).
rewrite [LHS]compA.
rewrite [RHS]compA.
congr (_ \o _).
rewrite (FCompE U0 F0) -[in RHS](@functor_o U0) -[in LHS](@functor_o U0).
congr (_ # _).
by rewrite -(natural (AdjointFunctor.eta H)).
Qed.
HB.instance Definition _ := isNatural.Build _ _ uni_fun uni_naturality.

Let uni : @eta_type [the functor of F \o F0] [the functor of U0 \o U] :=
  [the nattrans _ [the functor of (U0 \o U) \o (F \o F0)] of uni_fun].

Definition couni_fun : ((F \o F0) \o (U0 \o U)) ~~> idfun :=
  fun A : UU0 => eps A \o F # eps0 (U A).

Lemma couni_naturality :
  naturality [the functor of (F \o F0) \o (U0 \o U)] _ couni_fun.
Proof.
move=> A B h.
rewrite [LHS]compA.
rewrite {}(natural (AdjointFunctor.eps H)).
rewrite -[LHS]compA.
rewrite -[RHS]compA; congr (_ \o _).
rewrite [in LHS]FCompE -[in LHS](@functor_o F) [in LHS](natural (AdjointFunctor.eps H0)).
by rewrite -[in RHS](@functor_o F).
Qed.
HB.instance Definition _ := isNatural.Build _ _ couni_fun couni_naturality.

Let couni : @eps_type [the functor of F \o F0] [the functor of U0 \o U] :=
  [the _ ~> _ of couni_fun].

Lemma composite_adjoint : [the functor of F \o F0] -| [the functor of U0 \o U].
Proof.
apply: (@AdjointFunctor.mk _ _ uni couni).
  rewrite /TriangularLaws.left => A.
  (*rewrite /couni /uni /=.*)
  rewrite FCompE -[LHS]compA.
  rewrite -(@functor_o F).
  rewrite (_ : @eps0 _ \o F0 # _ = @eta (F0 A)); first exact: (AdjointFunctor.tri_left H).
  rewrite functor_o [LHS]compA -FCompE.
  rewrite -(natural (AdjointFunctor.eps H0)) /= FIdE -compA.
  by rewrite (AdjointFunctor.tri_left H0) compfid.
rewrite /TriangularLaws.right => A.
rewrite /couni /uni /=.
rewrite compA -[RHS](AdjointFunctor.tri_right H0 (U A)); congr (_ \o _).
rewrite FCompE -functor_o; congr (_ # _).
rewrite functor_o -compA -FCompE.
rewrite (natural (AdjointFunctor.eta H)) FIdE.
by rewrite compA (AdjointFunctor.tri_right H) compidf.
Qed.

End composite_adjoint.

Definition operation (E : functor) (M : monad) := [the functor of E \o M] ~> M.
Notation "E .-operation M" := (operation E M).

Section algebraicity.
Variables (E : functor) (M : monad).
Definition algebraicity (op : (*E.-operation M*)E \o M ~~> M) :=
  forall (A B : UU0) (f : A -> M B) (t : E (M A)),
    op A t >>= f = op B ((E # (fun m => m >>= f)) t).
End algebraicity.

HB.mixin Record isAOperation (E : functor) (M : monad) (op : E \o M ~~> M) := {
  algebraic : algebraicity op }.
HB.structure Definition AOperation (E : functor) (M : monad) :=
  {op of isAOperation E M op &
         isNatural [the functor of E \o M] M op (*NB: this is an operation in fact*)}.
Notation aoperation := AOperation.type.
Arguments algebraic {E} {M} s.

(*Module AOperation.
Section aoperation.
Variables (E : functor) (M : monad).
Record mixin_of (op : E \O M ~> M) := Mixin { _ : algebraicity op }.
Record class_of (op : E \O M ~~> M) := Class {
  base : Natural.mixin_of op ;
  mixin : mixin_of (Natural.Pack base) }.
Structure t := Pack { m : E \O M ~~> M ; class : class_of m }.
Definition baseType (o : t) := Natural.Pack (base (class o)).
End aoperation.
Module Exports.
Arguments m {E} {M}.
Notation aoperation := t.
Coercion baseType : aoperation >-> nattrans.
Canonical baseType.
End Exports.
End AOperation.
Export AOperation.Exports.*)

Notation "E .-aoperation M" := (aoperation E M).

Section algebraic_operation_interface.
Variables (E : functor) (M : monad) (op : E.-aoperation M).
Lemma aoperation_ext (f g : E.-aoperation M) :
  f = g <-> forall a, (f a = g a :> (_ -> _)).
Proof.
split => [ -> // |]; move: f g => [f Hf] [g Hg] /= fg.
have ? : f = g by exact: funext_dep.
subst g; congr (AOperation.Pack _).
case: Hf => -[Hf1] [Hf2].
case: Hg => -[Hg1] [Hg2].
by f_equal; f_equal; exact/proof_irr.
Qed.

End algebraic_operation_interface.

(* TODO:
Lemma monad_of_ret_bind_ext (F G : functor) (RET1 : FId ~> F) (RET2 : FId ~> G)
  (bind1 : forall A B : UU0, F A -> (A -> F B) -> F B)
  (bind2 : forall A B : UU0, G A -> (A -> G B) -> G B) :
  forall (FG : F = G),
  RET1 = eq_rect _ (fun m : functor => FId ~> m) RET2 _ ((*beuh*) (esym FG)) ->
  bind1 = eq_rect _ (fun m : functor => forall A B : UU0, m A -> (A -> m B) -> m B) bind2 _ (esym FG) ->
  forall H1 K1 H2 K2 H3 K3,
  Monad_of_ret_bind F RET1 bind1 H1 H2 H3 =
  Monad_of_ret_bind G RET2 bind2 K1 K2 K3.
Proof.
move=> FG; subst G; move=> HRET; subst RET1; move=> HBIND; subst bind1 => H1 K1 H2 K2 H3 K3.
rewrite /Monad_of_ret_bind; congr Monad.Pack; simpl in *.
have <- : H1 = K1 by exact/proof_irr.
have <- : H2 = K2 by exact/proof_irr.
have <- : H3 = K3 by exact/proof_irr.
by [].
Qed. *)

(*
(* monads on Type are strong monads *)
Section strength.
Variable M : monad.
Definition strength A B (xy : (A * M B)%type) : M (A * B)%type :=
  let (x,my) := xy in my >>= (fun y => Ret (x,y)).
Lemma strengthE A B (x:A) (my:M B) : strength (x,my) = my >>= (fun y => Ret (x,y)).
Proof. done. Qed.
Lemma strength_unit A : snd = M # snd \o strength (A:=unit) (B:=A).
Proof.
apply functional_extensionality => x.
case: x => i ma.
rewrite compE strengthE.
rewrite -fmapE fmap_bind fcomp_def.
rewrite bindE.
have ->: Join ((M # (M # snd \o (fun y : A => Ret (i, y)))) ma) =
((M # snd \o Join) \o M # (fun y : A => Ret (i, y))) ma
  by rewrite functor_o join_naturality.
rewrite functor_o.
have ->: ((M # snd \o Join) \o (M # Ret \o M # pair i)) ma =
(M # snd \o (Join \o M # Ret) \o M # pair i) ma by done.
rewrite joinMret compfid.
rewrite -functor_o.
have ->: snd \o pair i = id by done.
by rewrite functor_id.
Qed.
End strength.
*)

Definition mpair {M : monad} {A} (xy : (M A * M A)%type) : M (A * A)%type :=
  let (mx, my) := xy in
  mx >>= (fun x => my >>= fun y => Ret (x, y)).

Lemma mpairE (M : monad) A (mx my : M A) :
  mpair (mx, my) = mx >>= (fun x => my >>= fun y => Ret (x, y)).
Proof. by []. Qed.

Lemma naturality_mpair (M : monad) (A B : UU0) (f : A -> B) (g : A -> M A):
  (M # f^`2) \o (mpair \o g^`2) = mpair \o ((M # f) \o g)^`2.
Proof.
apply funext => -[a0 a1].
rewrite compE fmap_bind.
rewrite compE mpairE compE bind_fmap; bind_ext => a2.
rewrite fcompE fmap_bind 2!compE bind_fmap; bind_ext => a3.
by rewrite fcompE -(compE (M # f^`2)) (natural ret) FIdE.
Qed.

Definition commute {M : monad} A B (m : M A) (n : M B) C (f : A -> B -> M C) : Prop :=
  m >>= (fun x => n >>= (fun y => f x y)) = n >>= (fun y => m >>= (fun x => f x y)) :> M _.

Definition preserves {M : monad} (A B : UU0) (f : A -> M A) (g : A -> B) :=
  forall x, (f x >>= fun y => Ret (y, g y)) = (f x >>= fun y => Ret (y, g x)).

(*Local Notation "[ \o f , .. , g , h ]" := (f \o .. (g \o h) ..)
  (at level 0) (*, format "[ \o '['  f , '/' .. , '/' g , '/' h ']' ]"
  ).*) : test_scope.

Local Open Scope test_scope.

Lemma naturality_mpair' (M : monad) A B (f : A -> B) (g : A -> M A):
  (M # f^`2) \o (mpair \o g^`2) = mpair \o ((M # f) \o g)^`2.
Proof.
rewrite funeqE => -[a0 a1].
change ((M # f^`2 \o (mpair \o g^`2)) (a0, a1)) with
    ((M # f^`2) (mpair (g a0, g a1))).
change ((mpair \o (M # f \o g)^`2) (a0, a1)) with
    (mpair ((M # f \o g) a0,(M # f \o g) a1)).
rewrite !mpairE.
rewrite !bindE.
evar (T : Type);evar (RHS : A -> T).
have ->: (fun x : A => do y <- g a1; Ret (x, y)) = RHS.
  rewrite funeqE => x; rewrite bindE.
  rewrite functor_o.
  change (Join ([\o M # Ret,M # pair x] (g a1))) with
        ([\o Join,M # Ret,M # pair x] (g a1)).
    rewrite joinMret'.
  exact: erefl.
rewrite /RHS {RHS}; rewrite {T}.
change ((M # f^`2) (Join ((M # (fun x : A => (M # pair x) (g a1))) (g a0)))) with
    ((M # f^`2 \o Join) ((M # (fun x : A => (M # pair x) (g a1))) (g a0))).
rewrite join_naturality.
evar (T : Type);evar (RHS : T).
have->:(M # (fun x : B => do y <- (M # f \o g) a1; Ret (x, y))) = RHS.
- rewrite functor_o.
  rewrite bindE'.
  rewrite functor_o.
  exact: erefl.
rewrite/RHS{RHS};rewrite{T}.
change
  (
    Join
    (((M # Join \o M # (Fun M (B:=M (B * B)%type))^~ ((M # f \o g) a1)) \o
        M # (fun x y : B => Ret (x, y))) ((M # f \o g) a0))
  ) with
    (
      (
        [ \o Join ,
          (M # Join) ,
          (M # (Fun M (B:=M (B * B)%type))^~ ((M # f \o g) a1)) ,
          (M # (fun x y : B => Ret (x, y))) ,
          (M # f \o g) ]
      ) a0)
    .
rewrite joinA'.
(*
rewrite fmap_bind. compE [in RHS]/= bind_fmap; bind_ext => a2.
rewrite fcompE fmap_bind compE bind_fmap; bind_ext => a3.
by rewrite fcompE -(compE (fmap M # f^`2)) fmap_ret.
Qed.
*)
Abort.

Local Close Scope test_scope.
*)

Section rep.
Context {M : monad}.

Fixpoint rep n (mx : M unit) := if n is n.+1 then mx >> rep n mx else skip.

Lemma repS mx n : rep n.+1 mx = rep n mx >> mx.
Proof.
elim: n => /= [|n IH]; first by rewrite bindmskip bindskipf.
by rewrite bindA IH.
Qed.

Lemma rep1 mx : rep 1 mx = mx. Proof. by rewrite repS bindskipf. Qed.

Lemma rep_addn m n mx : rep (m + n) mx = rep m mx >> rep n mx.
Proof.
elim: m n => [|m IH /=] n; by
  [rewrite bindskipf add0n | rewrite -addnE IH bindA].
Qed.

End rep.

(* example from Gibbons and Hinze, ICFP 2011 *)
Section MonadCount.

Variable M : monad.
Variable tick : M unit.

Fixpoint hanoi n : M unit :=
  if n is n.+1 then hanoi n >> tick >> hanoi n else skip.

Lemma hanoi_rep n : hanoi n = rep (2 ^ n).-1 tick.
Proof.
elim: n => // n IH /=.
rewrite IH -repS prednK ?expn_gt0 // -rep_addn.
by rewrite -subn1 addnBA ?expn_gt0 // addnn -muln2 -expnSr subn1.
Qed.

End MonadCount.
