From mathcomp Require Import all_ssreflect.
From mathcomp Require boolp.
Require Import monae_lib hierarchy monad_lib fail_lib state_lib monad_model.

(******************************************************************************)
(*                    Formalization of monad transformers                     *)
(*                                                                            *)
(* This file corresponds to the formalization of [Mauro Jaskelioff, Modular   *)
(* Monad Transformers, ESOP 2009] (roughly, up to Sect. 5, Example 22). Up to *)
(* Sect. 4, it is documented in [Célestine Sauvage, Reynald Affeldt, David    *)
(* Nowak, Vers la formalisation en Coq des transformateurs de monades         *)
(* modulaires, JFLA 2020]. From functorial monad transformers, this is work   *)
(* in progress.                                                               *)
(*                                                                            *)
(*             monadM == monad morphism                                       *)
(*             monadT == monad transformer                                    *)
(*                       instances: stateT, errorT (exception), envT          *)
(*                       (environment), outputT, contT (continuation)         *)
(*            lifting == lifting of a sigma-operation along a monad morphism  *)
(*   E .-aoperation M == algebraic E.-operation M                             *)
(* uniform_algebric_lifting == Theorem: lifting of an algebraic operations    *)
(*                       along a monad morphism                               *)
(*                FMT == functorial monad transformer                         *)
(*                       instances: errorFMT, stateFMT, envFMT, outputFMT     *)
(*                                                                            *)
(******************************************************************************)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope monae_scope.

Reserved Notation "E .-aoperation M" (at level 2, format "E  .-aoperation  M").

Module MonadMLaws.
Section monadmlaws.
Variables (M N : monad).
Definition ret (e : M ~~> N) := forall A : UU0, e A \o Ret = Ret.
Definition bind (e : M ~~> N) := forall (A B : UU0) (m : M A) (f : A -> M B),
    e B (m >>= f) = e A m >>= (e B \o f).
End monadmlaws.
End MonadMLaws.

Module monadM.
Section monadm.
Variables (M N : monad).
Record mixin_of (e : M ~~> N) := Mixin
  {_ : MonadMLaws.ret e ; _ : MonadMLaws.bind e }.
Structure t := Pack { e : M ~~> N ; class : mixin_of e }.
End monadm.
Module Exports.
Notation monadM := t.
Coercion e : monadM >-> Funclass.
End Exports.
End monadM.
Export monadM.Exports.

Section monadM_interface.
Variables (M N : monad) (f : monadM M N).
Lemma monadMret A : f A \o Ret = Ret.
Proof. by case: f => ? []. Qed.
Lemma monadMbind A B (m : M A) (h : A -> M B) :
  f _ (m >>= h) = f _ m >>= (f _ \o h).
Proof. by case: f => ? []. Qed.
End monadM_interface.

Section monadM_lemmas.
Variables (M N : monad) (e : monadM M N).
Lemma natural_monadM : naturality M N e.
Proof.
move=> A B h; rewrite boolp.funeqE => m /=.
by rewrite !fmapE monadMbind (compA (e B)) monadMret.
Qed.
End monadM_lemmas.

Canonical monadM_nt (M N : monad) (e : monadM M N) : M ~> N :=
  Natural.Pack (Natural.Mixin (natural_monadM e)).

Module MonadT.
Record mixin_of (T : monad -> monad) := Mixin {
  liftT : forall M : monad, monadM M (T M) }.
Record t := Pack {m : monad -> monad ; class : mixin_of m}.
Module Exports.
Notation monadT := t.
Coercion m : monadT >-> Funclass.
Definition Lift (T : t) : forall M : monad, monadM M (m T M) :=
  let: Pack _ (Mixin f) := T return forall M : monad, monadM M (m T M) in f.
Arguments Lift _ _ : simpl never.
End Exports.
End MonadT.
Export MonadT.Exports.

Section state_monad_transformer.

Local Obligation Tactic := idtac.

Variables (S : UU0) (M : monad).

Definition MS := fun A : UU0 => S -> M (A * S)%type.

Definition retS (A : UU0) : A -> MS A := curry Ret.

Definition bindS A B (m : MS A) f : MS B := fun s => m s >>= uncurry f.

Definition MS_map (A B : UU0) (f : A -> B) (m : MS A) : MS B :=
  (M # (fun x => (f x.1, x.2))) \o m.

Lemma MS_map_i : FunctorLaws.id MS_map.
Proof.
move=> A; rewrite boolp.funeqE => m.
rewrite /MS_map boolp.funeqE => s.
rewrite (_ : (fun x : A * S => _) = id) ?functor_id //.
by rewrite boolp.funeqE; case.
Qed.

Lemma MS_map_o : FunctorLaws.comp MS_map.
Proof.
move=> A B C g h; rewrite /MS_map boolp.funeqE => m.
by rewrite boolp.funeqE => s /=; rewrite -[RHS]compE -functor_o.
Qed.

Definition MS_functor := Functor.Pack (Functor.Mixin MS_map_i MS_map_o).

Lemma naturality_retS : naturality FId MS_functor retS.
Proof.
move=> A B h; rewrite /Actm /= boolp.funeqE => a /=.
rewrite /MS_map /= boolp.funeqE => s /=.
by rewrite /retS [in LHS]curryE (natural RET).
Qed.

Definition retS_natural : FId ~> MS_functor :=
  Natural.Pack (Natural.Mixin naturality_retS).

Program Definition stateTmonad : monad :=
  @Monad_of_ret_bind MS_functor retS_natural bindS _ _ _.
Next Obligation.
by move=> A B a f; rewrite /bindS boolp.funeqE => s; rewrite bindretf.
Defined.
Next Obligation.
move=> A m; rewrite /bindS boolp.funeqE => s.
rewrite -[in RHS](bindmret (m s)); by bind_ext; case.
Defined.
Next Obligation.
move=> A B C m f g; rewrite /bindS boolp.funeqE => s.
by rewrite bindA; bind_ext; case.
Defined.

Definition liftS A (m : M A) : stateTmonad A :=
  fun s => m >>= (fun x => Ret (x, s)).

Program Definition stateTmonadM : monadM M stateTmonad :=
  locked (monadM.Pack (@monadM.Mixin _ _ liftS _ _)).
Next Obligation.
move=> A.
rewrite /liftS boolp.funeqE => a /=; rewrite boolp.funeqE => s /=.
by rewrite bindretf.
Qed.
Next Obligation.
move=> A B m f; rewrite /liftS boolp.funeqE => s.
rewrite [in RHS]/Bind [in RHS]/Join /= /Monad_of_ret_bind.join /= /bindS !bindA.
bind_ext => a; by rewrite !bindretf.
Qed.

End state_monad_transformer.

Definition stateT S : monadT := MonadT.Pack (MonadT.Mixin (stateTmonadM S)).

Lemma liftSE S (M : monad) U (m : M U) : liftS m = Lift (stateT S) M U m.
Proof.
case: M m => [M [[f fi fo] [r j a b c]]] m.
by rewrite /= /Lift /= /stateTmonadM; unlock.
Qed.

Section exception_monad_transformer.

Local Obligation Tactic := idtac.

Variables (Z : UU0) (* the type of exceptions *) (M : monad).

Definition MX := fun X : UU0 => M (Z + X)%type.

Definition retX X x : MX X := Ret (inr x).

Definition bindX X Y (t : MX X) (f : X -> MX Y) : MX Y :=
  t >>= fun c => match c with inl z => Ret (inl z) | inr x => f x end.

Local Open Scope mprog.
Definition MX_map (A B : UU0) (f : A -> B) : MX A -> MX B :=
  M # (fun x => match x with inl y => inl y | inr y => inr (f y) end).
Local Close Scope mprog.

Lemma MX_map_i : FunctorLaws.id MX_map.
Proof.
move=> A; rewrite boolp.funeqE => x.
rewrite /MX in x *.
by rewrite /MX_map (_ : (fun _ => _) = id) ?functor_id // boolp.funeqE; case.
Qed.

Lemma MX_map_o : FunctorLaws.comp MX_map.
Proof.
rewrite /MX_map => A B C g h /=.
rewrite boolp.funeqE => x /=.
rewrite -[RHS]compE -functor_o /=; congr (_ # _).
by rewrite boolp.funeqE; case.
Qed.

Definition MX_functor := Functor.Pack (Functor.Mixin MX_map_i MX_map_o).

Lemma naturality_retX : naturality FId MX_functor retX.
Proof.
move=> A B h; rewrite /retX boolp.funeqE /= => a.
by rewrite /Actm /= /MX_map -[LHS]compE (natural RET).
Qed.

Definition retX_natural : FId ~> MX_functor :=
  Natural.Pack (Natural.Mixin naturality_retX).

Program Definition errorTmonad : monad :=
  @Monad_of_ret_bind MX_functor retX_natural bindX _ _ _.
Next Obligation. by move=> A B a f; rewrite /bindX bindretf. Qed.
Next Obligation.
move=> A m; rewrite /bindX -[in RHS](bindmret m); by bind_ext; case.
Qed.
Next Obligation.
move=> A B C m f g; rewrite /bindX bindA; bind_ext; case => //.
by move=> z; rewrite bindretf.
Qed.

Definition liftX X (m : M X) : errorTmonad X :=
  m >>= (@RET errorTmonad _).

Program Definition errorTmonadM : monadM M errorTmonad :=
  monadM.Pack (@monadM.Mixin _ _ liftX _ _).
Next Obligation.
by move=> A; rewrite boolp.funeqE => a; rewrite /liftX /= bindretf.
Qed.
Next Obligation.
move=> A B m f; rewrite /liftX [in RHS]/Bind [in RHS]/Join /=.
rewrite  /Monad_of_ret_bind.join /= /bindX !bindA.
bind_ext => a; by rewrite !bindretf.
Qed.

End exception_monad_transformer.

Definition errorT Z := MonadT.Pack (MonadT.Mixin (@errorTmonadM Z)).

Lemma liftXE Z (M : monad) U (m : M U) : liftX _ m = Lift (errorT Z) M U m.
Proof. by []. Qed.

Section environment_monad_transformer.

Local Obligation Tactic := idtac.

Variables (R : UU0) (M : monad).

Definition MEnv := fun A : UU0 => R -> M A.

Definition retEnv (A : UU0) : A -> MEnv A := fun a r => Ret a.

Definition bindEnv A B (m : MEnv A) f : MEnv B := fun r => m r >>= (fun a => f a r).

Definition MEnv_map (A B : UU0) (f : A -> B) (m : MEnv A) : MEnv B :=
  (M # f) \o m.

Lemma MEnv_map_i : FunctorLaws.id MEnv_map.
Proof.
move=> A; rewrite boolp.funeqE => m.
by rewrite /MEnv_map functor_id compidf.
Qed.

Lemma MEnv_map_o : FunctorLaws.comp MEnv_map.
Proof.
move=> A B C g h; rewrite /MEnv_map boolp.funeqE => m /=.
by rewrite [in RHS]compA -functor_o.
Qed.

Definition MEnv_functor := Functor.Pack (Functor.Mixin MEnv_map_i MEnv_map_o).

Lemma naturality_retEnv : naturality FId MEnv_functor retEnv.
Proof.
move=> A B h; rewrite /Actm /= boolp.funeqE => a /=.
rewrite /MEnv_map /retEnv boolp.funeqE => r /=.
by rewrite -[LHS](compE _ Ret) natural FIdf.
Qed.

Definition retEnv_natural : FId ~> MEnv_functor :=
  Natural.Pack (Natural.Mixin naturality_retEnv).

Program Definition envTmonad : monad :=
  @Monad_of_ret_bind MEnv_functor retEnv_natural bindEnv _ _ _.
Next Obligation.
by move=> A B a f; rewrite /bindEnv boolp.funeqE => r; rewrite bindretf.
Defined.
Next Obligation.
move=> A m; rewrite /bindEnv boolp.funeqE => r.
rewrite -[in RHS](bindmret (m r)); by bind_ext; case.
Defined.
Next Obligation.
move=> A B C m f g; rewrite /bindEnv boolp.funeqE => r.
by rewrite bindA; bind_ext; case.
Defined.

Definition liftEnv A (m : M A) : envTmonad A :=
  fun r => m.

Program Definition envTmonadM : monadM M envTmonad :=
  locked (monadM.Pack (@monadM.Mixin _ _ liftEnv _ _)).
Next Obligation.
by [].
Qed.
Next Obligation.
move=> A B m f; rewrite /liftEnv boolp.funeqE => r.
rewrite [in RHS]/Bind [in RHS]/Join /= /Monad_of_ret_bind.join /= /bindEnv !bindA.
bind_ext => a; by rewrite !bindretf.
Qed.

End environment_monad_transformer.

Definition envT E : monadT := MonadT.Pack (MonadT.Mixin (envTmonadM E)).

Lemma liftEnvE E (M : monad) U : @liftEnv _ _ _ = Lift (envT E) M U.
Proof.
case: M => [M [[f fi fo] [r j a b c]]].
by rewrite /= /Lift /= /envTmonadM; unlock.
Qed.

(* traces monad transformer? *)
Section output_monad_transformer.

Local Obligation Tactic := idtac.

Variables (R : UU0) (M : monad).

Definition MO (X : UU0) := M (X * seq R)%type.

Definition retO (A : UU0) : A -> MO A := fun a => Ret (a, [::]).

Definition bindO A B (m : MO A) (f : A -> MO B) : MO B :=
  m >>= (fun o => let: (x, w) := o in f x >>=
  (fun o' => let (x', w') := o' in Ret (x', w ++ w'))).

Definition MO_map (A B : UU0) (f : A -> B) (m : MO A) : MO B :=
  (M # (fun x => (f x.1, x.2))) m.

Lemma MO_map_i : FunctorLaws.id MO_map.
Proof.
move=> A; rewrite boolp.funeqE => m.
rewrite /MO_map (_ : (fun _ => _) = id) ?functor_id//.
by rewrite boolp.funeqE; case.
Qed.

Lemma MO_map_o : FunctorLaws.comp MO_map.
Proof.
move=> A B C g h; rewrite /MO_map boolp.funeqE => m /=.
by rewrite -[in RHS](compE _ (M # _)) -functor_o.
Qed.

Definition MO_functor := Functor.Pack (Functor.Mixin MO_map_i MO_map_o).

Lemma naturality_retO : naturality FId MO_functor retO.
Proof.
move=> A B h; rewrite /Actm /= boolp.funeqE => a /=.
by rewrite /MO_map /retO -[LHS](compE _ Ret) natural FIdf.
Qed.

Definition retO_natural : FId ~> MO_functor :=
  Natural.Pack (Natural.Mixin naturality_retO).

Program Definition outputTmonad : monad :=
  @Monad_of_ret_bind MO_functor retO_natural bindO _ _ _.
Next Obligation.
move=> A B a f; rewrite /bindO /= bindretf /=.
rewrite (_ : (fun o' : B * seq R => _) = (fun o => Ret o)) ?bindmret //.
by rewrite boolp.funeqE; case.
Defined.
Next Obligation.
move=> A m; rewrite /bindO /= /retO /= -[RHS]bindmret.
by bind_ext => -[a w]; rewrite bindretf cats0.
Defined.
Next Obligation.
move=> A B C m f g; rewrite /bindO /=.
rewrite bindA; bind_ext; case=> x w.
rewrite !bindA; bind_ext; case=> x' w'.
rewrite !bindA bindretf; bind_ext; case=> x'' w''.
by rewrite bindretf catA.
Defined.

Definition liftO A (m : M A) : outputTmonad A :=
  m >>= (fun x => Ret (x, [::])).

Program Definition outputTmonadM : monadM M outputTmonad :=
  locked (monadM.Pack (@monadM.Mixin _ _ liftO _ _)).
Next Obligation.
move=> a; rewrite /liftO /= /retO boolp.funeqE => o /=.
by rewrite bindretf.
Qed.
Next Obligation.
move=> A B m f; rewrite /liftO /=.
rewrite bindA.
rewrite [in RHS]/Bind [in RHS]/Join /= /Monad_of_ret_bind.join /= /bindO !bindA.
bind_ext => a; rewrite !bindretf bindA /=; bind_ext => b.
by rewrite bindretf.
Qed.

End output_monad_transformer.

Definition outputT R : monadT := MonadT.Pack (MonadT.Mixin (outputTmonadM R)).

Lemma liftOE R (M : monad) U : @liftO _ _ _ = Lift (outputT R) M U.
Proof.
case: M => [M [[f fi fo] [r j a b c]]].
by rewrite /= /Lift /= /outputTmonadM; unlock.
Qed.

Section continuation_monad_tranformer.

Local Obligation Tactic := idtac.

Variables (r : UU0) (M : monad).

Definition MC : UU0 -> UU0 := fun A => (A -> M r) -> M r %type.

Definition retC (A : UU0) (a : A) : MC A := fun k => k a.

Definition bindC A B (m : MC A) f : MC B := fun k => m (f^~ k).

Definition MC_map (A B : UU0) (f : A -> B) (m : MC A) : MC B.
move=> Br; apply m => a.
apply Br; exact: (f a).
Defined.

Definition MC_functor : functor.
apply: (Functor.Pack (@Functor.Mixin MC MC_map _ _)).
by [].
by [].
Defined.

Lemma naturality_retC : naturality FId MC_functor retC.
Proof. by []. Qed.

Definition retC_natural : FId ~> MC_functor :=
  Natural.Pack (Natural.Mixin naturality_retC).

Program Definition contTmonad : monad :=
  @Monad_of_ret_bind MC_functor retC_natural bindC _ _ _.
Next Obligation. by []. Qed.
Next Obligation. by []. Qed.
Next Obligation. by []. Qed.

Definition liftC A (x : M A) : contTmonad A := fun k => x >>= k.

Program Definition contTmonadM : monadM M contTmonad :=
  monadM.Pack (@monadM.Mixin _ _ liftC  _ _).
Next Obligation.
move => A.
rewrite /liftC boolp.funeqE => a /=.
rewrite boolp.funeqE => s.
by rewrite bindretf.
Qed.
Next Obligation.
move => A B m f.
rewrite /liftC boolp.funeqE => cont.
by rewrite !bindA.
Qed.

End continuation_monad_tranformer.

Definition contT r := MonadT.Pack (MonadT.Mixin (contTmonadM r)).

Definition abortT r X (M : monad) A : contT r M A := fun _ : A -> M r => Ret X.
Arguments abortT {r} _ {M} {A}.

Section continuation_monad_transformer_examples.

Fixpoint for_loop (M : monad) (it min : nat) (body : nat -> contT unit M unit) : M unit :=
  if it <= min then Ret tt
  else if it is it'.+1 then
      (body it') (fun _ => for_loop it' min body)
      else Ret tt.

Section for_loop_lemmas.
Variable M : monad.
Implicit Types body : nat  -> contT unit M unit.

Lemma loop0 i body : for_loop i i body = Ret tt.
Proof.
by case i => //= n; rewrite ltnS leqnn.
Qed.

Lemma loop1 i j body : for_loop (i.+1 + j) i body =
  (body (i + j)) (fun _ => for_loop (i + j) i body).
Proof.
rewrite /=.
by case : ifPn ; rewrite ltnNge leq_addr.
Qed.

Lemma loop2 i j body :
  body (i + j) = abortT tt -> for_loop (i + j).+1 i body = Ret tt.
Proof.
move=> Hbody /=.
case : ifPn => Hcond.
- reflexivity.
- by rewrite Hbody /= /abortT.
Qed.

End for_loop_lemmas.
(* TODO : instantiate with RunStateMonad *)

Definition foreach (M : monad) (items : list nat) (body : nat -> contT unit M unit) : M unit :=
  foldr
    (fun x next => (body x) (fun _ => next))
    (Ret tt)
    items.

(* Lemma loop3 : forall i j body, *)
(*      foreach (i + j).+1 i body = Ret tt -> body (i + j) = @abort_tt m unit. *)
(* Proof. *)
(* move => i j body /=. *)
(* case : ifPn => //; rewrite ltnNge; rewrite leq_addr. *)
(* by []. *)
(* move => _ /= Hfor. *)
(* have Hcont2 : forall cont, body (i + j) = @abort_tt m unit -> body (i + j) cont = Ret tt. *)
(*   (* split. *) *)
(*   rewrite /= /abort_tt /abort. *)
(*   by rewrite funeqE. *)
(* have Hcont1 : (forall cont, body (i + j) cont = Ret tt) -> body (i + j) = @abort_tt m unit.   *)
(*   move => Hcont. *)
(*   rewrite /= /abort_tt /abort. *)
(*   rewrite funeqE => k. *)
(*   exact: Hcont. *)
(* apply Hcont1. *)
(* move => cont. *)
(* rewrite Hcont2 //. *)

(* set bl := (fun _ : unit => foreach (i + j) i body). *)
(* (* Check (fun _ : unit => foreach (i + j) i body). *) *)
(* generalize (Hcont1 bl). *)

(* move => bl. *)
(* Qed *)

Section sum.
Variables M : stateMonad nat.

Let sum n : M unit := for_loop n O
  (fun i : nat => liftC (Get >>= (fun z => Put (z + i)) ) ).

Lemma sum_test n :
  sum n = Get >>= (fun m => Put (m + sumn (iota 0 n))).
Proof.
elim: n => [|n ih].
  rewrite /sum.
  rewrite loop0.
  rewrite (_ : sumn (iota 0 0) = 0) //.
  rewrite -[LHS]bindskipf.
  rewrite -getputskip.
  rewrite bindA.
  bind_ext => a.
  rewrite addn0.
  rewrite -[RHS]bindmret.
  bind_ext.
  by case.
rewrite /sum -add1n loop1 /liftC bindA; bind_ext => m.
rewrite -/(sum n) {}ih -bindA putget bindA bindretf putput.
congr Put.
rewrite add0n (addnC 1).
rewrite iota_add /= sumn_cat /=.
by rewrite add0n addn0 /= addnAC addnA.
Qed.

Example sum_from_0_to_10 : M unit :=
  foreach (iota 100 0) (fun i => if i > 90 then
                            abortT tt
                          else
                            liftC (Get >>= (fun z => Put (z + i)))).

End sum.

End continuation_monad_transformer_examples.

Lemma functor_ext (F G : functor) :
  forall (H : Functor.acto F = Functor.acto G),
  Functor.actm (Functor.class G) =
  eq_rect _ (fun m : UU0 -> UU0 => forall A B : UU0, (A -> B) -> m A -> m B) (Functor.actm (Functor.class F)) _ H  ->
  G = F.
Proof.
move: F G => [F [HF1 HF2 HF3]] [G [HG1 HG2 HG3]] /= H; subst G => /= ?; subst HG1.
congr (Functor.Pack (Functor.Mixin _ _)); exact/boolp.Prop_irrelevance.
Defined.

Lemma natural_ext (F G G' : functor) (t : F ~> G) (t' : F ~> G') :
  forall (H : G = G'),
  forall (K : forall X (x : F X), Natural.cpnt t' x = eq_rect _ (fun m : functor => m X) (Natural.cpnt t x) _ H),
  t' = eq_rect _ (fun m => F ~> m) t _ H.
Proof.
move : t t' => [t t1] [t' t'1] /= H; subst G' => H /=.
have ? : t = t'.
  apply FunctionalExtensionality.functional_extensionality_dep => A.
  apply FunctionalExtensionality.functional_extensionality => x.
  rewrite H.
  by rewrite -[in RHS]eq_rect_eq.
subst t'.
congr Natural.Pack; exact/boolp.Prop_irrelevance.
Qed.

Lemma natural_ext2 (F F' : functor) (t : F \O F ~> F) (t' : F' \O F' ~> F') :
  forall (K : F = F'),
  forall L : (forall X (x : (F' \O F') X),
    Natural.cpnt t' x = eq_rect _ (fun m : functor => m X)
      (Natural.cpnt t (eq_rect _ (fun m : functor => (m \O m) X) x _ (esym K)))
      _ K),
  t' = eq_rect _ (fun m => m \O m ~> m) t _ K.
Proof.
move: t t' => [t t1] [t' t'1] /= H L; subst F.
rewrite -[in RHS]eq_rect_eq /=.
have ? : t = t'.
  apply FunctionalExtensionality.functional_extensionality_dep => A.
  apply FunctionalExtensionality.functional_extensionality => x.
  rewrite L.
  by rewrite -[in RHS]eq_rect_eq.
subst t'.
congr Natural.Pack; exact/boolp.Prop_irrelevance.
Qed.

Lemma monad_of_ret_bind_ext (F G : functor) (RET1 : FId ~> F) (RET2 : FId ~> G)
  (bind1 : forall A B : UU0, F A -> (A -> F B) -> F B)
  (bind2 : forall A B : UU0, G A -> (A -> G B) -> G B) :
  forall (FG : F = G),
  RET1 = eq_rect _ (fun m => FId ~> m) RET2 _ ((*beuh*) (esym FG)) ->
  bind1 = eq_rect _ (fun m : functor => forall A B : Type, m A -> (A -> m B) -> m B) bind2 _ (esym FG) ->
  forall H1 K1 H2 K2 H3 K3,
  @Monad_of_ret_bind F RET1 bind1 H1 H2 H3 =
  @Monad_of_ret_bind G RET2 bind2 K1 K2 K3.
Proof.
move=> FG; subst G; move=> HRET; subst RET1; move=> HBIND; subst bind1 => H1 K1 H2 K2 H3 K3.
rewrite /Monad_of_ret_bind; congr Monad.Pack; simpl in *.
have <- : H1 = K1 by exact/boolp.Prop_irrelevance.
have <- : H2 = K2 by exact/boolp.Prop_irrelevance.
have <- : H3 = K3 by exact/boolp.Prop_irrelevance.
by [].
Qed.

(* result of a discussion with Maxime and Enrico on 2019-09-12 *)
Section eq_rect_ret.
Variable X : UU0.
Let U  : UU1 := functor.
Let Q : U -> UU0 := Functor.acto^~ X.

Lemma eq_rect_ret (p p' : U) (K : Q p' = Q p) (x : Q p') (h : p = p') :
  x = eq_rect p Q (eq_rect _ (fun X : UU0 => id X) x _ K) p' h.
Proof.
rewrite /eq_rect; destruct h; rewrite (_ : K = erefl) //; exact/boolp.Prop_irrelevance.
Qed.

Lemma eq_rect_state_ret S (p := ModelMonad.State.functor S : U)
  (p' := MS_functor S ModelMonad.identity : U)
  (x : Q p') (h : p = p') : x = eq_rect p Q x p' h.
Proof.
have K : Q p' = Q p by [].
rewrite {2}(_ : x = eq_rect _ (fun x : UU0 => x) x _ K) //; first exact: eq_rect_ret.
rewrite /eq_rect (_ : K = erefl) //; exact/boolp.Prop_irrelevance.
Qed.

Lemma eq_rect_error_ret (E : UU0) (p : U := ModelMonad.Except.functor E)
  (p' : U := MX_functor E ModelMonad.identity)
  (x : Q p') (h : p = p') : x = eq_rect p Q x p' h.
Proof.
have K : Q p' = Q p by [].
rewrite {2}(_ : x = eq_rect _ (fun x : UU0 => x) x _ K) //; first exact: eq_rect_ret.
rewrite /eq_rect (_ : K = erefl) //; exact/boolp.Prop_irrelevance.
Qed.

Lemma eq_rect_cont_ret r (p : U := ModelMonad.Cont.functor r)
  (p' : U := MC_functor r ModelMonad.identity)
  (x : Q p') (h : p = p') : x = eq_rect p Q x p' h.
Proof.
have K : Q p' = Q p by [].
rewrite {2}(_ : x = eq_rect _ (fun x : UU0 => x) x _ K) //; first exact: eq_rect_ret.
rewrite /eq_rect (_ : K = erefl) //; exact/boolp.Prop_irrelevance.
Qed.

End eq_rect_ret.

Section eq_rect_bind.
Let U : Type := functor.
Let Q : U -> Type := fun F => forall A B, Functor.acto F A -> (A -> Functor.acto F B) -> Functor.acto F B.

Lemma eq_rect_bind (p p' : U) (K : Q p' = Q p) (x : Q p') (h : p = p') :
  x = eq_rect p Q (eq_rect _ id x _ K) p' h.
Proof.
rewrite /eq_rect; destruct h; rewrite (_ : K = erefl) //; exact/boolp.Prop_irrelevance.
Qed.

Lemma eq_rect_bind_state S (p : U := ModelMonad.State.functor S)
  (p' : U := MS_functor S ModelMonad.identity)
  (x : Q p') (h : p = p') : x = eq_rect p Q x p' h.
Proof.
have K : Q p' = Q p by [].
rewrite {2}(_ : x = eq_rect _ id x _ K); first exact: eq_rect_bind.
rewrite /eq_rect (_ : K = erefl) //; exact/boolp.Prop_irrelevance.
Qed.

Lemma eq_rect_bind_error E (p : U := ModelMonad.Except.functor E)
  (p' : U := MX_functor E ModelMonad.identity)
  (x : Q p') (h : p = p') : x = eq_rect p Q x p' h.
Proof.
have K : Q p' = Q p by [].
rewrite {2}(_ : x = eq_rect _ id x _ K) //; first exact: eq_rect_bind.
rewrite /eq_rect (_ : K = erefl) //; exact/boolp.Prop_irrelevance.
Qed.

Lemma eq_rect_bind_cont S (p : U := ModelMonad.Cont.functor S)
  (p' : U := MC_functor S ModelMonad.identity)
  (x : Q p') (h : p = p') : x = eq_rect p Q x p' h.
Proof.
have K : Q p' = Q p by [].
rewrite {2}(_ : x = eq_rect _ id x _ K) //; first exact: eq_rect_bind.
rewrite /eq_rect (_ : K = erefl) //; exact/boolp.Prop_irrelevance.
Qed.

End eq_rect_bind.

Section instantiations_with_the_identity_monad.

Lemma state_monad_stateT S :
  stateT S ModelMonad.identity = ModelMonad.State.t S.
Proof.
rewrite /= /stateTmonadM /ModelMonad.State.t.
have FG : MS_functor S ModelMonad.identity = ModelMonad.State.functor S.
  apply: functor_ext => /=.
  apply FunctionalExtensionality.functional_extensionality_dep => A.
  apply FunctionalExtensionality.functional_extensionality_dep => B.
  rewrite boolp.funeqE => f; rewrite boolp.funeqE => m; rewrite boolp.funeqE => s.
  by rewrite /MS_map /Actm /= /ModelMonad.State.map; destruct (m s).
apply (@monad_of_ret_bind_ext _ _ _ _ _ _ FG) => /=.
  apply/natural_ext => A a /=; exact: eq_rect_state_ret _ (esym FG).
set x := @bindS _ _; exact: (@eq_rect_bind_state S x (esym FG)).
Qed.

Lemma error_monad_errorT (Z : UU0) :
  errorT Z ModelMonad.identity = ModelMonad.Except.t Z.
Proof.
rewrite /= /errorTmonadM /ModelMonad.Except.t.
have FG : MX_functor Z ModelMonad.identity = ModelMonad.Except.functor Z.
  apply: functor_ext => /=.
  apply FunctionalExtensionality.functional_extensionality_dep => A.
  apply FunctionalExtensionality.functional_extensionality_dep => B.
  rewrite boolp.funeqE => f; rewrite boolp.funeqE => m.
  by rewrite /MX_map /Actm /= /ModelMonad.Except.map; destruct m.
apply (@monad_of_ret_bind_ext _ _ _ _ _ _ FG) => /=.
  apply/natural_ext => A a /=; exact: (eq_rect_error_ret _ (esym FG)).
set x := @bindX _ _; exact: (@eq_rect_bind_error Z x (esym FG)).
Qed.

Lemma cont_monad_contT r :
  contT r ModelMonad.identity = ModelMonad.Cont.t r.
Proof.
rewrite /= /contTmonadM /ModelMonad.Cont.t.
have FG : MC_functor r ModelMonad.identity = ModelMonad.Cont.functor r.
  apply: functor_ext => /=.
  apply FunctionalExtensionality.functional_extensionality_dep => A.
  apply FunctionalExtensionality.functional_extensionality_dep => B.
  by rewrite boolp.funeqE => f; rewrite boolp.funeqE => m.
apply (@monad_of_ret_bind_ext _ _ _ _ _ _ FG) => /=.
  apply/natural_ext => A a /=; exact: (@eq_rect_cont_ret A r _ (esym FG)).
set x := @bindC _ _; exact: (@eq_rect_bind_cont r x (esym FG)).
Qed.

End instantiations_with_the_identity_monad.

Section calcul.

Let contTi := @contT^~ ModelMonad.identity.
Let callcci := ModelCont.callcc.

Definition break_if_none (m : monad) (break : _) (acc : nat) (x : option nat) : m nat :=
  if x is Some x then Ret (x + acc) else break acc.

Definition sum_until_none (xs : seq (option nat)) : contTi nat nat :=
  callcci (fun break : nat -> contTi nat nat => foldM (break_if_none break) 0 xs).

Goal sum_until_none [:: Some 2; Some 6; None; Some 4] = @^~ 8.
by cbv.
Abort.

Definition calcul : contTi nat nat :=
  (contTi _ # (fun x => 8 + x))
  (callcci (fun k : _ -> contTi nat _ => (k 5) >>= (fun y => Ret (y + 4)))).

Goal calcul = @^~ 13.
by cbv.
Abort.

End calcul.

Section lifting.
Variables (E : functor) (M : monad) (op : E.-operation M)
          (N : monad) (e : monadM M N).
Definition lifting (f : E \O N ~~> N) :=
  forall X : UU0, e X \o op X = f X \o (E # e X).
End lifting.

Section liftingt.
Variables (E : functor) (M : monad) (op : E.-operation M)
          (t : monadT).
Definition lifting_monadT := lifting op (Lift t M).
End liftingt.

Section algebraicity.
Variables (E : functor) (M : monad).
Definition algebraicity (op : E.-operation M) :=
  forall (A B : UU0) (f : A -> M B) (t : E (M A)),
    op A t >>= f = op B ((E # (fun m => m >>= f)) t).
End algebraicity.

Module AOperation.
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
Export AOperation.Exports.

Notation "E .-aoperation M" := (aoperation E M).

Section algebraic_operation_interface.
Variables (E : functor) (M : monad) (op : E.-aoperation M).
Lemma algebraic : algebraicity op.
Proof. by case: op => ? [? []]. Qed.
Lemma aoperation_ext (f g : E.-aoperation M) :
  f = g <-> forall a, (f a = g a :> (_ -> _)).
Proof.
split => [ -> // |]; move: f g => [f Hf] [g Hg] /= fg.
have ? : f = g by exact: FunctionalExtensionality.functional_extensionality_dep.
subst g; congr (AOperation.Pack _); exact/boolp.Prop_irrelevance.
Qed.

End algebraic_operation_interface.

Section algebraic_operation_examples.

Lemma algebraic_empty : algebraicity ListOps.empty_op.
Proof. by []. Qed.

Lemma algebraic_append : algebraicity ListOps.append_op.
Proof.
move=> A B f [t1 t2] /=.
rewrite !bindE /= /ModelMonad.ListMonad.bind /= /Actm /=.
rewrite /Monad_of_ret_bind.Map /=.
rewrite /ModelMonad.ListMonad.bind /= /ModelMonad.ListMonad.ret /=.
by rewrite -flatten_cat -map_cat /= -flatten_cat -map_cat.
Qed.

Lemma algebraic_output L : algebraicity (@OutputOps.output_op L).
Proof.
move=> A B f [w [x w']].
rewrite bindE /= /OutputOps.output /= bindE /= !cats0.
by case: f => x' w''; rewrite catA.
Qed.

(* NB: flush is not algebraic *)
Lemma algebraic_flush L : algebraicity (@OutputOps.flush_op L).
Proof.
move=> A B f [x w].
rewrite /OutputOps.flush_op /=.
rewrite /OutputOps.flush /=.
rewrite /Actm /=.
rewrite bindE /=.
rewrite /OutputOps.Flush.actm.
rewrite bindE /=.
rewrite cats0.
case: f => x' w'.
Abort.

Lemma algebraic_throw Z : algebraicity (@ExceptOps.throw_op Z).
Proof. by []. Qed.

Definition throw_aop Z : (ExceptOps.Throw.func Z).-aoperation (ModelMonad.Except.t Z) :=
  AOperation.Pack (AOperation.Class (AOperation.Mixin (@algebraic_throw Z))).

(* NB: handle is not algebraic *)
Lemma algebraic_handle Z : algebraicity (@ExceptOps.handle_op Z).
Proof.
move=> A B f t.
rewrite /ExceptOps.handle_op /=.
rewrite /ExceptOps.handle /=.
rewrite /uncurry /prod_curry.
case: t => -[z//|a] g /=.
rewrite bindE /=.
case: (f a) => // z.
rewrite bindE /=.
rewrite /ModelMonad.Except.bind /=.
rewrite /Actm /=.
rewrite /Monad_of_ret_bind.Map /=.
rewrite /ModelMonad.Except.bind /=.
case: (g z) => [z0|a0].
Abort.

Lemma algebraic_ask E : algebraicity (@EnvironmentOps.ask_op E).
Proof. by []. Qed.

(* NB: local is not algebraic *)
Lemma algebraic_local E : algebraicity (@EnvironmentOps.local_op E).
Proof.
move=> A B f t.
rewrite /EnvironmentOps.local_op /=.
rewrite /EnvironmentOps.local /=.
rewrite boolp.funeqE => e /=.
rewrite bindE /=.
rewrite /ModelMonad.Environment.bind /=.
rewrite /Actm /=.
rewrite /Monad_of_ret_bind.Map /=.
rewrite /ModelMonad.Environment.bind /=.
rewrite /ModelMonad.Environment.ret /=.
rewrite /EnvironmentOps.Local.actm /=.
case: t => /= ee m.
rewrite bindE /=.
rewrite /ModelMonad.Environment.bind /=.
rewrite /Actm /=.
rewrite /Monad_of_ret_bind.Map /=.
rewrite /ModelMonad.Environment.bind /=.
rewrite /ModelMonad.Environment.ret /=.
Abort.

Lemma algebraic_get S : algebraicity (@StateOps.get_op S).
Proof. by []. Qed.

Definition get_aop S : (StateOps.Get.func S).-aoperation (ModelMonad.State.t S) :=
  AOperation.Pack (AOperation.Class (AOperation.Mixin (@algebraic_get S))).

Lemma algebraic_put S : algebraicity (@StateOps.put_op S).
Proof. by move=> ? ? ? []. Qed.

Definition put_aop S : (StateOps.Put.func S).-aoperation (ModelMonad.State.t S) :=
  AOperation.Pack (AOperation.Class (AOperation.Mixin (@algebraic_put S))).

Lemma algebraicity_abort r : algebraicity (ContOps.abort_op r).
Proof. by []. Qed.

Definition abort_aop r : (ContOps.Abort.func r).-aoperation (ModelMonad.Cont.t r) :=
  AOperation.Pack (AOperation.Class (AOperation.Mixin (@algebraicity_abort r))).

Lemma algebraicity_callcc r : algebraicity (ContOps.acallcc_op r).
Proof. by []. Qed.

Definition callcc_aop r : (ContOps.Acallcc.func r).-aoperation (ModelMonad.Cont.t r) :=
  AOperation.Pack (AOperation.Class (AOperation.Mixin (@algebraicity_callcc r))).

End algebraic_operation_examples.

Section proposition17.

Section psi.
Variables (E : functor) (M : monad).

Definition psi' (n : E ~~> M) : E \O M ~~> M :=
  fun X => Join \o n (M X).

Lemma natural_psi' (n : E ~> M) : naturality (E \O M) M (psi' n).
Proof.
move=> A B h; rewrite /psi'.
rewrite -/(Join \o n (M A)) compA natural.
by rewrite -compA (natural n).
Qed.

Definition psi0 (n : E ~> M) : E.-operation M := Natural.Pack (Natural.Mixin (natural_psi' n)).

Lemma algebraic_psi0 (n : E ~> M) : algebraicity (psi0 n).
Proof.
move=> A B g t.
rewrite bindE /Bind.
rewrite -(compE (M # g)).
rewrite compA.
rewrite /=.
rewrite -[in X in _ = Join X]compE.
rewrite -[in RHS](natural n).
transitivity (Join ((M # (Join \o (M # g))) (n (M A) t))) => //.
rewrite -[in X in Join X = _]compE.
rewrite (natural JOIN).
rewrite functor_o.
rewrite -[in RHS]FCompE.
rewrite -[RHS]compE.
rewrite [in RHS]compA.
by rewrite joinA.
Qed.

Definition psi (n : E ~> M) : E.-aoperation M :=
  AOperation.Pack (AOperation.Class (AOperation.Mixin (algebraic_psi0 n))).

Lemma psiE (n : E ~> M) A : (psi n) A = Join \o n (M A).
Proof. by []. Qed.

End psi.

Section phi.
Variables (E : functor) (M : monad).

Definition phi' (op : E.-operation M) : E ~~> M := fun X => op X \o (E # Ret).

Lemma natural_phi' (op : E.-operation M) : naturality E M (phi' op).
Proof.
move=> A B h; rewrite /phi'.
rewrite compA.
rewrite (natural op).
rewrite -compA.
rewrite -[in RHS]compA.
congr (_ \o _).
rewrite /=.
rewrite -2!(functor_o E).
rewrite (natural RET).
by rewrite FIdf.
Qed.

Definition phi (op : E.-operation M) : E ~> M :=
  Natural.Pack (Natural.Mixin (natural_phi' op)).

Lemma phiE (op : E.-operation M) X : phi op X = op X \o (E # Ret).
Proof. by []. Qed.

End phi.

Section bijection.
Variables (E : functor) (M : monad).

Lemma psiK (op : E ~> M) : phi (psi op) = op.
Proof.
apply/nattrans_ext => A.
rewrite phiE psiE boolp.funeqE => m /=.
rewrite -(compE (op _)) -(natural op) -(compE Join).
by rewrite compA joinMret.
Qed.

Lemma phiK (op : E.-aoperation M) : psi (phi op) = op.
Proof.
apply/aoperation_ext => A.
rewrite psiE phiE boolp.funeqE => m /=.
rewrite -(compE (op _)) joinE (algebraic op).
rewrite -(compE (E # _)) -functor_o.
rewrite -(compE (op _)).
rewrite /Bind.
rewrite (_ : (fun _ => Join _) = Join \o (M # id)) //.
rewrite -(compA Join).
rewrite functor_id.
rewrite compidf.
by rewrite joinretM functor_id compfid.
Qed.

End bijection.
End proposition17.

Section uniform_algebric_lifting.
Variables (E : functor) (M : monad) (op : E.-aoperation M).
Variables (N : monad) (e : monadM M N).

Definition alifting : E.-aoperation N := psi (monadM_nt e \v phi op).

Lemma aliftingE :
  alifting = (fun X => Join \o e (N X) \o phi op (N X)) :> (_ ~~> _).
Proof. by []. Qed.

Theorem uniform_algebric_lifting : lifting op e alifting.
Proof.
move=> X.
rewrite boolp.funeqE => Y.
rewrite /alifting !compE psiE vcompE phiE !compE.
rewrite (_ : (E # Ret) ((E # e X) Y) =
             (E # (M # e X)) ((E # Ret) Y)); last first.
  rewrite -[in LHS]compE -functor_o.
  rewrite -[in RHS]compE -functor_o.
  rewrite (natural RET).
  by rewrite FIdf.
rewrite (_ : op (N X) ((E # (M # e X)) ((E # Ret) Y)) =
             (M # e X) (op (M X) ((E # Ret) Y))); last first.
  rewrite -(compE (M # e X)).
  by rewrite (natural op).
transitivity (e X (Join (op (M X) ((E # Ret) Y)))); last first.
  rewrite joinE monadMbind.
  rewrite bindE -(compE _ (M # e X)).
  by rewrite -natural.
by rewrite -[in LHS](phiK op).
Qed.
End uniform_algebric_lifting.

Section examples_of_algebraic_lifting.

Section state_errorT.
Let M S : monad := ModelState.state S.

Definition aLGet {Z S} : (StateOps.Get.func S).-aoperation (errorT Z (M S)) :=
  alifting (get_aop S) (Lift (errorT Z) (M S)).

Definition aLPut {Z S} : (StateOps.Put.func S).-operation (errorT Z (M S)) :=
  alifting (put_aop S) (Lift (errorT Z) (M S)).

Goal forall Z (S : UU0) X (k : S -> errorT Z (M S) X), aLGet _ k = StateOps.get_op _ k.
by [].
Abort.

Goal forall Z S, aLGet _ Ret = Lift (errorT Z) (M S) _ (@ModelState.get S).
by [].
Abort.

End state_errorT.

Section continuation_stateT.
Variable (r S : UU0).
Let M : monad := ModelCont.t r.
Let stS : monadT := stateT S.

Definition aLCallcc : (ContOps.Acallcc.func r).-aoperation (stS M) :=
  alifting (callcc_aop r) (Lift stS M).

Goal forall A (f : (stS M A -> r) -> stS M A),
  aLCallcc _ f = (fun s k => f (fun m => uncurry m (s, k)) s k) :> stS M A.
move=> A f.
by rewrite /aLCallcc /= /stS /= /stateT /= /stateTmonadM /=; unlock.
Abort.

Definition usual_callccS (A B : UU0) (f : (A -> stS M B) -> stS M A) : stS M A :=
  fun s k => f (fun x _ _ => k (x, s)) s k.

Lemma callccS_E A B f : @aLCallcc _
    (fun k : stS M A -> r =>
       f (fun x => (fun (_ : S) (_ : B * S -> r) => k (@RET (stS M) A x)) : stS M B)) =
  usual_callccS f.
Proof.
by rewrite /aLCallcc /= /stS /= /stateT /= /stateTmonadM /=; unlock.
Qed.

End continuation_stateT.

End examples_of_algebraic_lifting.

Section example_stateT.

Definition stateMonad_of_stateT_mixin S (M : monad) :
  MonadState.mixin_of S (stateT S M).
Proof.
refine (@MonadState.Mixin _ (stateT S M) (fun s => Ret (s, s))
    (fun s' _ => Ret (tt, s')) _ _ _ _).
- move=> s s'.
  rewrite boolp.funeqE => s0.
  case: M => m [f [/= r j a b c]].
  rewrite /Bind /Join /JOIN /stateTmonad /Monad_of_ret_bind /bindS /Actm /=.
  by rewrite /Monad_of_ret_bind.Map bindretf /= /retS bindretf.
- move=> s.
  rewrite boolp.funeqE => s0.
  case: M => m [f [/= r j a b c]].
  rewrite /retS /Ret /RET /Bind /stateTmonad /Monad_of_ret_bind /Actm /=.
  by rewrite /bindS /= /Monad_of_ret_bind.Map 4!bindretf.
- rewrite boolp.funeqE => s.
  case: M => m [f [/= r j a b c]].
  rewrite /Bind /Join /JOIN /= /stateTmonad /Monad_of_ret_bind /bindS /Actm /=.
  by rewrite /Monad_of_ret_bind.Map bindretf /= /retS bindretf.
- case: M => m [f [/= r j a b c]] A k.
  rewrite boolp.funeqE => s.
  rewrite /Bind /Join /JOIN /= /bindS /stateTmonad /= /Monad_of_ret_bind.
  rewrite /Actm /Monad_of_ret_bind.Map /= /Monad_of_ret_bind.Map /= /bindS /=.
  by rewrite !bindretf /= !bindretf.
Qed.

Canonical stateMonad_of_stateT S M :=
  MonadState.Pack (MonadState.Class (stateMonad_of_stateT_mixin S M)).

Lemma bindLfailf (M : failMonad) S T U (m : stateT S M U) :
  Lift (stateT S) M T Fail >> m = Lift (stateT S) M U Fail.
Proof.
rewrite -!liftSE /liftS boolp.funeqE => s.
rewrite bindfailf {1}/Bind /= /bindS /=.
rewrite [X in _ X s](_ : _ = (fun _ => Fail)); last first.
  by rewrite boolp.funeqE => s'; rewrite bindfailf.
rewrite (_ : _ _ s = Fail) ?bindfailf //.
by rewrite /Actm /= /Monad_of_ret_bind.Map /= /bindS bindfailf.
Qed.

Variable M : failMonad.
Let N : monad := stateT nat M.

Let incr : N unit := Get >>= (Put \o succn).
Let prog T : N unit := incr >> Lift (stateT nat) M T Fail >> incr.

Goal forall T, prog T = Lift (stateT nat) M unit Fail.
Proof.
move=> T; rewrite /prog.
rewrite bindA.
rewrite bindLfailf.
Abort.

End example_stateT.

Section example_errorT.

Definition failMonad_of_errorT_mixin (M : monad) :
  MonadFail.class_of (errorT unit M).
Proof.
refine (@MonadFail.Class _ _
  (@MonadFail.Mixin (errorT unit M)
                    (fun B => Ret (@inl _ B tt))
                    _ )).
move=> A B.
case: M => m [f [/= r j a b c]] g.
rewrite /Bind /= /bindX /= /errorTmonad /Monad_of_ret_bind /= /Actm /=.
by rewrite /Monad_of_ret_bind.Map /= /bindX /= !bindretf.
Qed.

Canonical failMonad_of_errorT M := MonadFail.Pack (failMonad_of_errorT_mixin M).

Definition LGet S (M : stateMonad S) := Lift (errorT unit) M S (@Get S M).
Definition LPut S (M : stateMonad S) := Lift (errorT unit) M unit \o (@Put S M).

Variable M : stateMonad nat.
Let N : monad := errorT unit M.
Let incr : N unit := LGet M >>= (LPut M \o succn).
Let prog T : N unit := incr >> (Fail : _ T) >> incr.

End example_errorT.

Definition natural_hmap_lift (t : monadT)
    (h : forall (M N : monad), (M ~> N) -> (t M ~> t N)) :=
  forall (M N : monad) (n : M ~> N) X,
    h M N n X \o Lift t M X = Lift t N X \o n X.

Module Fmt.
Section functorial_monad_transformer.
Record mixin_of (t : monadT) := Class {
  hmap : forall (M N : monad), (M ~> N) -> (t M ~> t N) ;
  _ : forall M N (e : monadM M N), MonadMLaws.ret (hmap (monadM_nt e)) ;
  _ : forall M N (e : monadM M N), MonadMLaws.bind (hmap (monadM_nt e)) ;
  _ : forall (M : monad), hmap (NId M) = NId (t M) ;
  _ : forall (M N P : monad) (t : M ~> N) (s : N ~> P), hmap s \v hmap t = hmap (s \v t) ;
  _ : natural_hmap_lift hmap }.
Structure t := Pack { m : monadT ; class : mixin_of m }.
End functorial_monad_transformer.
Module Exports.
Notation FMT := t.
Definition Hmap (T : t) : forall (M N : monad), (M ~> N) -> (m T M ~> m T N) :=
  let: Pack _ (Class f _ _ _ _ _) := T return forall (M N : monad), (M ~> N) -> (m T M ~> m T N) in f.
Arguments Hmap _ _ : simpl never.
Coercion m : FMT >-> monadT.
End Exports.
End Fmt.
Export Fmt.Exports.

Section fmt_lemmas.
Lemma fmt_ret (t : FMT) M N (e : monadM M N) :
  MonadMLaws.ret (Hmap t (monadM_nt e)).
Proof. by case: t M N e => m []. Qed.
Lemma fmt_bind (t : FMT) M N (e : monadM M N) :
  MonadMLaws.bind (Hmap t (monadM_nt e)).
Proof. by case: t M N e => m []. Qed.
Lemma fmt_NId (t : FMT) (M : monad) : Hmap t (NId M) = NId (t M).
Proof. by case: t M => m []. Qed.
Lemma fmt_vcomp (t : FMT) (M N P : monad) (n : M ~> N) (s : N ~> P) :
  Hmap t s \v Hmap t n = Hmap t (s \v n).
Proof. by case: t M N P n s => m []. Qed.
Lemma natural_hmap (T : FMT) : natural_hmap_lift (Hmap T).
Proof. by case: T => [? []]. Qed.
End fmt_lemmas.

Section error_FMT.
Variable X : UU0.
Let T : monadT := errorT X.
Let hmapX' (F G : monad) (tau : F ~> G) (A : UU0) (t : T F A) : T G A :=
  tau _ t.

Lemma natural_hmapX' (F G : monad) (tau : F ~> G) :
  naturality (T F) (T G) (hmapX' tau).
Proof.
move=> A B h.
rewrite /hmapX' -2!FunctionalExtensionality.eta_expansion.
have H : forall G, errorT X G # h = MX_map h.
  move=> E; rewrite boolp.funeqE => m /=.
  rewrite /Actm /= /Monad_of_ret_bind.Map /MX_map /= /bindX /= fmapE.
  congr (_ >>= _).
  by rewrite boolp.funeqE; case.
by rewrite 2!H /MX_map /= natural.
Qed.

Definition hmapX (F G : monad) (tau : F ~> G) : T F ~> T G :=
  Natural.Pack (Natural.Mixin (natural_hmapX' tau)).

Let monadMret_hmapX (F G : monad) (e : monadM F G) :
  MonadMLaws.ret (hmapX (monadM_nt e)).
Proof.
move=> A; rewrite boolp.funeqE => /= a.
by rewrite /hmapX' /retX /= -(compE (e _)) monadMret.
Qed.

Let monadMbind_hmapX (F G : monad) (e : monadM F G) :
  MonadMLaws.bind (hmapX (monadM_nt e)).
Proof.
move=> A B m f; rewrite /hmapX /=.
rewrite !bindE /= /bindX /=.
rewrite !monadMbind /=.
rewrite !bindA /=.
congr (_ >>= _).
rewrite boolp.funeqE.
case.
  move=> x.
  rewrite bindretf.
  rewrite -(compE (e _)) monadMret.
  rewrite bindretf /=.
  by rewrite -(compE (e _)) monadMret.
move=> a.
rewrite /retX bindretf /=.
rewrite -(compE (e _)) monadMret.
by rewrite bindretf.
Qed.

Let hmapX_NId (M : monad) : hmapX (NId M) = NId (T M).
Proof. by apply nattrans_ext. Qed.

Let hmapX_v (M N P : monad) (t : M ~> N) (s : N ~> P) :
  hmapX s \v hmapX t = hmapX (s \v t).
Proof. exact/nattrans_ext. Qed.

Let hmapX_lift : natural_hmap_lift hmapX.
Proof.
move=> M N t A.
rewrite /hmapX.
rewrite /Lift /= /liftX /=.
rewrite /retX /=.
rewrite /Bind /=.
rewrite (_ : (fun x : A => Ret (inr x)) = Ret \o inr) //.
rewrite (_ : (fun m : Monad.acto M A => Join ((M # (Ret \o inr)) m)) =
             Join \o (M # (Ret \o inr)) ) //.
rewrite functor_o.
rewrite (compA Join).
rewrite joinMret.
rewrite compidf.
rewrite (_ : (fun m : N A => Join _) = Join \o (N # (Ret \o inr))) //.
rewrite functor_o.
rewrite (compA Join).
rewrite joinMret.
rewrite compidf.
by rewrite natural.
Qed.

Program Definition errorFMT : FMT := @Fmt.Pack (errorT X)
  (@Fmt.Class _ (fun M N nt => hmapX nt) monadMret_hmapX
    monadMbind_hmapX _ hmapX_v hmapX_lift).

End error_FMT.

Lemma liftFMTXE X (M : monad) U : @liftX _ _ _ = Lift (errorFMT X) M U.
Proof. by []. Qed.

Section Fmt_stateT.
Variable S : UU0.
Let T : monadT := stateT S.
Definition hmapS' (F G : monad) (tau : F ~> G) (A : UU0) (t : T F A) : T G A :=
  fun s => tau _ (t s).

Lemma natural_hmapS' (F G : monad) (tau : F ~> G) :
  naturality (T F) (T G) (hmapS' tau).
Proof.
move=> A B h.
rewrite /hmapS'.
rewrite /=.
have H : forall G, stateTmonad S G # h = MS_functor S G # h.
  move=> H; rewrite boolp.funeqE => m.
  rewrite /Actm /=.
  rewrite /Monad_of_ret_bind.Map /=.
  rewrite /bindS /MS_map /retS /=.
  rewrite boolp.funeqE => s.
  set j := uncurry _.
  have -> : j = Ret \o (fun x : A * S => (h x.1, x.2)).
    by rewrite boolp.funeqE; case.
  by rewrite -fmapE.
rewrite !H {H}.
rewrite {1}/MS_functor /= {1}/Actm /=.
rewrite /MS_map boolp.funeqE => m; rewrite boolp.funeqE => s /=.
rewrite -(compE  _ (tau (A * S)%type)).
by rewrite natural.
Qed.

Definition hmapS (F G : monad) (tau : F ~> G) : T F ~> T G :=
  Natural.Pack (Natural.Mixin (natural_hmapS' tau)).

Let monadMret_hmapS (F G : monad) (e : monadM F G) :
  MonadMLaws.ret (hmapS (monadM_nt e)).
Proof.
move=> A; rewrite boolp.funeqE => /= a.
rewrite /hmapS' /= /retS /= boolp.funeqE => s.
by rewrite [in LHS]curryE monadMret.
Qed.

Let monadMbind_hmapS (F G : monad) (e : monadM F G) :
  MonadMLaws.bind (hmapS (monadM_nt e)).
Proof.
move=> A B m f.
rewrite /hmapS /= boolp.funeqE => s.
rewrite !bindE /= /bindS /=.
rewrite !monadMbind /=.
rewrite !bindA /=.
congr (_ >>= _).
rewrite boolp.funeqE; case => a s'.
rewrite /retS /=.
rewrite bindretf.
rewrite -(compE _ Ret).
rewrite /uncurry /prod_curry.
rewrite -bind_fmap.
rewrite monadMret.
rewrite -(compE _ Ret).
rewrite natural.
rewrite FIdf.
rewrite bindE.
rewrite -(compE _ Ret).
rewrite -(compE _ (_ \o _)).
rewrite natural.
rewrite compA.
rewrite joinretM.
rewrite FIdf.
by rewrite compidf.
Qed.

Let hmapS_NId (M : monad) : hmapS (NId M) = NId (T M).
Proof. by apply nattrans_ext. Qed.

Let hmapS_v (M N P : monad) (t : M ~> N) (s : N ~> P) :
  hmapS s \v hmapS t = hmapS (s \v t).
Proof. exact/nattrans_ext. Qed.

Let hmapS_lift : natural_hmap_lift hmapS.
Proof.
move=> M N t A.
rewrite /hmapS /= /hmapS'.
rewrite /Lift /=.
rewrite /stateTmonadM /=.
unlock.
rewrite /=.
rewrite /liftS /=.
rewrite /Bind /=.
rewrite boolp.funeqE => ma /=.
rewrite boolp.funeqE => s /=.
rewrite 2!(_ : (fun x : A => Ret (x, s)) = Ret \o (fun x => (x, s))) //.
rewrite functor_o.
rewrite -(compE Join).
rewrite compA.
rewrite joinMret.
rewrite compidf.
rewrite functor_o.
rewrite -(compE Join).
rewrite compA.
rewrite joinMret.
rewrite compidf.
rewrite -(compE _ (t A)).
by rewrite natural.
Qed.

Program Definition stateFMT : FMT := @Fmt.Pack T
  (@Fmt.Class _ (fun M N nt => hmapS nt) monadMret_hmapS
    monadMbind_hmapS _ hmapS_v hmapS_lift).

End Fmt_stateT.

Section Fmt_envT.
Variable E : UU0.
Let T : monadT := envT E.
Definition hmapEnv' (F G : monad) (tau : F ~> G) (A : UU0) (t : T F A) : T G A :=
  fun s => tau _ (t s).

Lemma natural_hmapEnv' (F G : monad) (tau : F ~> G) :
  naturality (T F) (T G) (hmapEnv' tau).
Proof.
move=> A B h.
rewrite /hmapEnv'.
rewrite /=.
have H : forall G, envTmonad E G # h = MEnv_functor E G # h.
  move=> H; rewrite boolp.funeqE => m.
  rewrite /Actm /=.
  rewrite /Monad_of_ret_bind.Map /=.
  rewrite /bindEnv /MEnv_map /retEnv /= boolp.funeqE => s.
  by rewrite (_ : (fun a : A => _) = Ret \o h) // -fmapE.
rewrite !H {H}.
rewrite {1}/MEnv_functor /= {1}/Actm /=.
rewrite /MEnv_map boolp.funeqE => m; rewrite boolp.funeqE => s /=.
rewrite -(compE  _ (tau A)).
by rewrite natural.
Qed.

Definition hmapEnv (F G : monad) (tau : F ~> G) : T F ~> T G :=
  Natural.Pack (Natural.Mixin (natural_hmapEnv' tau)).

Let monadMret_hmapEnv (F G : monad) (e : monadM F G) :
  MonadMLaws.ret (hmapEnv (monadM_nt e)).
Proof.
move=> A; rewrite boolp.funeqE => /= a.
rewrite /hmapEnv' /= /retEnv /= boolp.funeqE => s.
by rewrite -[LHS](compE _ Ret) monadMret.
Qed.

Let monadMbind_hmapEnv (F G : monad) (e : monadM F G) :
  MonadMLaws.bind (hmapEnv (monadM_nt e)).
Proof.
move=> A B m f.
rewrite /hmapEnv /= boolp.funeqE => s.
rewrite !bindE /= /bindEnv /=.
rewrite !monadMbind /=.
rewrite !bindA /=.
congr (_ >>= _).
rewrite boolp.funeqE => a.
rewrite /retEnv /=.
rewrite bindretf.
rewrite -(compE _ Ret).
rewrite -bind_fmap.
rewrite monadMret.
rewrite -(compE _ Ret).
rewrite natural.
rewrite FIdf.
rewrite bindE.
rewrite -(compE _ Ret).
rewrite -(compE _ (_ \o _)).
rewrite natural.
rewrite compA.
rewrite joinretM.
rewrite FIdf.
by rewrite compidf.
Qed.

Let hmapEnv_NId (M : monad) : hmapEnv (NId M) = NId (T M).
Proof. by apply nattrans_ext. Qed.

Let hmapEnv_v (M N P : monad) (t : M ~> N) (s : N ~> P) :
  hmapEnv s \v hmapEnv t = hmapEnv (s \v t).
Proof. exact/nattrans_ext. Qed.

Let hmapEnv_lift : natural_hmap_lift hmapEnv.
Proof.
move=> M N t A.
rewrite /hmapEnv /= /hmapEnv'.
rewrite /Lift /=.
rewrite /envTmonadM /=.
unlock.
rewrite /=.
rewrite /liftEnv /=.
rewrite /Bind /=.
by rewrite boolp.funeqE.
Qed.

Program Definition envFMT : FMT := @Fmt.Pack T
  (@Fmt.Class _ (fun M N nt => hmapEnv nt) monadMret_hmapEnv
    monadMbind_hmapEnv _ hmapEnv_v hmapEnv_lift).

End Fmt_envT.

Section Fmt_outputT.
Variable R : UU0.
Let T : monadT := outputT R.
Definition hmapO' (F G : monad) (tau : F ~> G) (A : UU0) (t : T F A) : T G A := tau _ t.

Lemma natural_hmapO' (F G : monad) (tau : F ~> G) :
  naturality (T F) (T G) (hmapO' tau).
Proof.
move=> A B h.
rewrite /hmapO'.
rewrite /=.
have H : forall G, outputTmonad R G # h = MO_functor R G # h.
  move=> H; rewrite boolp.funeqE => m.
  rewrite /Actm /=.
  rewrite /Monad_of_ret_bind.Map /=.
  rewrite /MO_map.
  rewrite /bindO /retO /=.
  rewrite fmapE.
  congr (_ >>= _).
  rewrite boolp.funeqE => -[x w].
  by rewrite bindretf cats0.
rewrite !H {H}.
rewrite {1}/MO_functor /= {1}/Actm /=.
rewrite /MO_map boolp.funeqE => m /=.
rewrite -[in LHS](compE  _ (tau _)).
by rewrite natural.
Qed.

Definition hmapO (F G : monad) (tau : F ~> G) : T F ~> T G :=
  Natural.Pack (Natural.Mixin (natural_hmapO' tau)).

Let monadMret_hmapO (F G : monad) (e : monadM F G) :
  MonadMLaws.ret (hmapO (monadM_nt e)).
Proof.
move=> A; rewrite boolp.funeqE => /= a.
rewrite /hmapO' /= /retO /=.
by rewrite -[LHS](compE _ Ret) monadMret.
Qed.

Let monadMbind_hmapO (F G : monad) (e : monadM F G) :
  MonadMLaws.bind (hmapO (monadM_nt e)).
Proof.
move=> A B m f.
rewrite /hmapO /=.
rewrite !bindE /= /bindO /=.
rewrite !monadMbind /=.
rewrite !bindA /=.
bind_ext => -[x w].
rewrite /retO /=.
rewrite bindretf.
rewrite -(compE _ Ret).
rewrite -bind_fmap.
rewrite monadMret.
rewrite -(compE _ Ret).
rewrite natural.
rewrite FIdf /=.
rewrite bindA.
rewrite !bindretf.
rewrite monadMbind /=.
bind_ext => -[x' w'] /=.
by rewrite cats0 -[LHS](compE _ Ret (x', _)) monadMret.
Qed.

Let hmapO_NId (M : monad) : hmapO (NId M) = NId (T M).
Proof. by apply nattrans_ext. Qed.

Let hmapO_v (M N P : monad) (t : M ~> N) (s : N ~> P) :
  hmapO s \v hmapO t = hmapO (s \v t).
Proof. exact/nattrans_ext. Qed.

Let hmapO_lift : natural_hmap_lift hmapO.
Proof.
move=> M N t A.
rewrite /hmapO /= /hmapO'.
rewrite /Lift /=.
rewrite /outputTmonadM /=.
unlock.
rewrite /=.
rewrite /liftO /=.
rewrite boolp.funeqE => ma /=.
rewrite -!fmapE.
rewrite -(compE _ (t A)).
by rewrite natural.
Qed.

Program Definition outputFMT : FMT := @Fmt.Pack T
  (@Fmt.Class _ (fun M N nt => hmapO nt) monadMret_hmapO
    monadMbind_hmapO _ hmapO_v hmapO_lift).

End Fmt_outputT.
