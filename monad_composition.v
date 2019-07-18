Require Import ssreflect ssrmatching ssrfun ssrbool.
From mathcomp Require Import eqtype ssrnat seq path div choice fintype tuple.
From mathcomp Require Import finfun bigop.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

(* jones and duponcheel, composing monads, sect 2, 3 *)

From monae Require Import monad.

Module Comp.
Section comp.
Variables (M N : monad).
Definition ret : FId ~> M \O N := fun _ => Ret \o Ret.
Arguments ret {_}.
Lemma fmap_ret A B (h : A -> B) : ((M \O N) # h) \o ret = ret \o h.
Proof.
rewrite {2}/ret -[in RHS]compA -(ret_naturality N h) [in RHS]compA.
by rewrite {1}/ret [in LHS]compA ret_naturality FIdf.
Qed.
End comp.
End Comp.
Arguments Comp.ret _ _ {_}.
Notation CRet := (Comp.ret).

Module Prod.
Section prod.
Variables M N(* NB: actually, premonad is enough for N*) : monad.
Variable prod : N \O (M \O N) ~> M \O N.
Arguments prod {_}.

Definition JOIN : (M \O N) \O (M \O N) ~> M \O N := fun _ => Join \o M # prod.
Arguments JOIN {_}.

Definition prod1 := forall A B (f : A -> B), prod \o N # ((M \O N) # f) = (M \O N) # f \o prod.
Definition prod2 := forall A, prod \o Ret = id :> (_ -> (M \O N) A).
Definition prod3 := forall A, prod \o N # CRet M N = Ret :> (_ -> (M \O N) A).
Definition prod4 := forall A, prod \o N # JOIN = JOIN \o prod :> (_ -> (M \O N) A).
Hypothesis Hprod1 : prod1.
Hypothesis Hprod2 : prod2.
Hypothesis Hprod3 : prod3.
Hypothesis Hprod4 : prod4.

Lemma JOIN_naturality : JoinLaws.join_naturality (@JOIN).
Proof.
move=> A B g; apply/esym; rewrite {1}/JOIN -[in LHS]compA -functor_o Hprod1.
by rewrite functor_o compA /JOIN FCompE -(FCompE M M) -(@join_naturality M _ _ (N # g)) -compA.
Qed.

Lemma JOIN_ret : JoinLaws.left_unit (@CRet M N) (@JOIN).
Proof.
move=> A; rewrite /JOIN /Comp.ret compA.
rewrite -(compA Join (M # prod) Ret) (ret_naturality M prod).
by rewrite compA (compA Join) joinretM compidf Hprod2.
Qed.

Lemma JOIN_fmap_ret : JoinLaws.right_unit (@CRet M N) (@JOIN).
Proof.
move=> A.
by rewrite /JOIN /Comp.ret -compA -functor_o Hprod3 joinMret.
Qed.

Lemma JOIN_fmap_JOIN : JoinLaws.associativity (@JOIN).
Proof.
move=> A; rewrite {1 2}/JOIN -[in LHS]compA.
rewrite -functor_o.
rewrite Hprod4.
rewrite {1}/JOIN.
rewrite -(compA Join (M # prod) prod).
rewrite functor_o.
rewrite compA.
rewrite joinA.
rewrite -compA.
rewrite functor_o.
rewrite (compA Join (_ # (_ # prod)) (_ # prod)).
by rewrite -join_naturality.
Qed.

End prod.
End Prod.

Module Dorp.
Section dorp.
Variables M  (* actually, premonad is enough for M *) N : monad.
Variable dorp : M \O (N \O M) ~> M \O N.
Arguments dorp {_}.

Definition JOIN : (M \O N) \O (M \O N) ~> M \O N := fun _ => M # Join \o dorp.
Arguments JOIN {_}.

Definition dorp1 := forall A B (f : A -> B), dorp \o (M \O N) # (M # f) = (M \O N) # f \o dorp.
Definition dorp2 := forall A, (@dorp A) \o CRet M N = M # Ret.
Definition dorp3 := forall A, (@dorp A) \o (M \O N) # Ret = id.
Definition dorp4 := forall A, (@dorp A) \o JOIN = JOIN \o (M \O N) # dorp.
Hypothesis Hdorp1 : dorp1.
Hypothesis Hdorp2 : dorp2.
Hypothesis Hdorp3 : dorp3.
Hypothesis Hdorp4 : dorp4.

Lemma join_naturality : JoinLaws.join_naturality (@JOIN).
Proof.
move=> A B g; apply/esym; rewrite {1}/JOIN -compA Hdorp1.
rewrite compA.
rewrite (FCompE M N (N # g)).
rewrite -(functor_o M).
rewrite -join_naturality.
by rewrite functor_o.
Qed.

Lemma JOIN_ret : JoinLaws.left_unit (@CRet M N) (@JOIN).
Proof.
move=> A; rewrite /JOIN -compA Hdorp2.
rewrite -(functor_o M).
by rewrite joinretM functor_id.
Qed.

Lemma JOIN_fmap_ret : JoinLaws.right_unit (@CRet M N) (@JOIN).
Proof.
move=> A; rewrite /JOIN /Comp.ret.
rewrite -(compA (M # Join) dorp).
rewrite (functor_o (M \O N)).
rewrite (compA dorp) Hdorp3.
rewrite compidf -functor_o.
by rewrite joinMret functor_id.
Qed.

Lemma JOIN_fmap_JOIN : JoinLaws.associativity (@JOIN).
Proof.
move=> A; rewrite {1 2}/JOIN.
rewrite FCompE.
rewrite (functor_o N).
rewrite -compA.
rewrite functor_o.
rewrite (compA dorp).
rewrite Hdorp1.
rewrite -(compA _ dorp).
rewrite (compA (M # Join)) -functor_o.
rewrite joinA.
rewrite functor_o.
rewrite -compA (compA (M # Join) dorp).
rewrite -/JOIN.
rewrite -Hdorp4.
by rewrite compA.
Qed.

End dorp.
End Dorp.

Module Swap.
Section swap.
Variables M N : monad.
Variable swap : N \O M ~> M \O N.
Arguments swap {_}.

Definition JOIN : (M \O N) \o (M \O N) ~> M \O N :=
  fun A => M # Join \o Join \o M # (@swap (N A)).

Lemma JOINE A : @JOIN A = Join \o M # (M # Join \o swap).
Proof.
rewrite /JOIN join_naturality.
by rewrite -(compA Join) FCompE -functor_o.
Qed.

Let prod A := M # (@Join N A) \o (@swap _).
Arguments prod {A}.
Let dorp A := Join \o M # (@swap A).
Arguments dorp {A}.

Fact JOIN_prod A : @JOIN A = Join \o M # prod.
Proof. by rewrite JOINE. Qed.

Fact JOIN_dorp A : @JOIN A = M # Join \o dorp.
Proof. by rewrite /dorp. Qed.

Definition swap1 := forall A B (f : A -> B), swap \o N # (M # f) = M # (N # f) \o swap .
Definition swap2 := forall A, @swap A \o Ret = M # Ret :> (M A -> (M \O N) A).
Definition swap3 := forall A, @swap A \o N # Ret = Ret :> (N A -> (M \O N) A).
Definition swap4 := forall A, (@prod A) \o N # (@dorp _) = (@dorp _) \o (@prod _).
Hypothesis Hswap1 : swap1.
Hypothesis Hswap2 : swap2.
Hypothesis Hswap3 : swap3.
Hypothesis Hswap4 : swap4.

Lemma prod1 : Prod.prod1 (@prod).
Proof.
move=> A B f; rewrite {1}/prod.
rewrite -compA Hswap1 (compA (M # Join)) -functor_o.
by rewrite -join_naturality functor_o -compA.
Qed.

Lemma prod2 : Prod.prod2 (@prod).
Proof. by move=> A; rewrite /prod -compA Hswap2 -(functor_o M) joinretM functor_id. Qed.

Lemma prod3 : Prod.prod3 (@prod).
Proof.
move=> A; rewrite /prod /Comp.ret.
rewrite (functor_o N) (compA (M # Join \o swap)) -(compA (_ # Join)) Hswap3.
by rewrite ret_naturality -compA joinMret compfid.
Qed.

Lemma prod4 : Prod.prod4 (@prod).
Proof.
move=> A; rewrite {1}/Prod.JOIN -JOIN_prod JOIN_dorp {1}/prod (functor_o N).
rewrite (compA (M # Join \o swap)) -(compA (_ # Join)) Hswap1.
rewrite (compA (M # Join)) -functor_o joinA functor_o.
rewrite -compA -(compA (_ # Join)) (compA (M # Join) swap) -/prod Hswap4.
by rewrite compA /Prod.JOIN -JOIN_prod JOIN_dorp.
Qed.

Lemma dorp1 : Dorp.dorp1 (@dorp).
Proof.
move=> A B g; rewrite {1}/dorp -compA -functor_o.
by rewrite Hswap1 functor_o (compA Join) -join_naturality -compA.
Qed.

Lemma dorp2 : Dorp.dorp2 (@dorp).
Proof.
move=> A; rewrite /dorp /Comp.ret (compA (Join \o M # swap)) -(compA Join).
by rewrite ret_naturality (compA Join) joinretM compidf Hswap2.
Qed.

Lemma dorp3 : Dorp.dorp3 (@dorp).
Proof.
by move=> A; rewrite /dorp -compA -functor_o Hswap3 joinMret.
Qed.

Lemma dorp4 : Dorp.dorp4 (@dorp).
Proof.
move=> A; rewrite {1}/dorp {1}/Dorp.JOIN -JOIN_dorp JOIN_prod.
rewrite (compA (Join \o M # swap)) -(compA Join) join_naturality.
rewrite (compA Join Join) -joinA -2!compA FCompE -functor_o -(functor_o M).
by rewrite compA -/dorp -Hswap4 functor_o compA -JOINE JOIN_dorp.
Qed.

Lemma JOIN_naturality : JoinLaws.join_naturality (@JOIN).
Proof. by move=> ?? g; rewrite JOINE -/prod (Prod.JOIN_naturality prod1 g) JOINE. Qed.

Lemma JOIN_ret : JoinLaws.left_unit (@CRet M N) (@JOIN).
Proof. by move=> A; rewrite JOINE -/prod (Prod.JOIN_ret prod2). Qed.

Lemma JOIN_fmap_ret : JoinLaws.right_unit (@CRet M N) (@JOIN).
Proof. by move=> A; rewrite JOINE -/prod (Prod.JOIN_fmap_ret prod3). Qed.

Lemma JOIN_fmap_JOIN : JoinLaws.associativity (@JOIN).
Proof. by move=> A; rewrite !JOINE -!/prod (Prod.JOIN_fmap_JOIN prod4). Qed.

End swap.
End Swap.

(* monad morphism, Jaskelioff ESOP 2009 *)

From mathcomp Require Import boolp.

Module monadM.
Section monad_morphism.
Variables M N : monad.
Record t := mk {
  e : M ~> N ;
  ret : forall {A} (a : A), Ret a = e (Ret a) ;
  bind : forall {A B} (m : M A) (f : A -> M B),
    e (m >>= f) = e m >>= (fun a => e (f a))
}.
End monad_morphism.
Module Exports.
Notation monadM := t.
Definition coercion := e.
Coercion coercion : monadM >-> Funclass.
End Exports.
End monadM.
Export monadM.Exports.

Section monadM_lemmas.
Variables M N : monad.
Lemma monadMret (f : monadM M N) : forall {A} (a : A), Ret a = f _ (Ret a).
Proof. by case: f. Qed.
Lemma monadMbind (f : monadM M N) : forall {A B} (m : M A) (h : A -> M B),
  f _ (m >>= h) = f _ m >>= (fun a => f _ (h a)).
Proof. by case: f. Qed.
End monadM_lemmas.

Section monad_morphism.
Variables M N : monad.

Lemma natural_monad_morphism (f : monadM M N) : naturalP M N f.
Proof.
move=> A B h; rewrite funeqE => m /=.
have <- : Join ((M # (Ret \o h)) m) = (M # h) m.
  by rewrite functor_o [LHS](_ : _ = (Join \o M # Ret) ((M # h) m)) // joinMret.
move: (@monadMbind M N f A B m (Ret \o h)); rewrite 2!bindE => ->.
rewrite (_ : (fun a => f _ ((Ret \o h) a)) = Ret \o h); last first.
  by rewrite funeqE => y; rewrite -monadMret.
rewrite [RHS](_ : _ = (Join \o (N # Ret \o N # h)) (f _ m)); last first.
  by rewrite compE functor_o.
by rewrite compA joinMret.
Qed.

End monad_morphism.

Module MonadT.
Section monad_transformer.
Record t := mk {
  T : monad -> monad ;
  retT : forall (M : monad), FId ~> (T M);
  bindT : forall (M : monad) A B, (T M) A -> (A -> (T M) B) -> (T M) B ;
  liftT : forall (M : monad), monadM M (T M) }.
End monad_transformer.
Module Exports.
Notation monadT := t.
Coercion T : monadT >-> Funclass.
End Exports.
End MonadT.
Export MonadT.Exports.

From mathcomp Require Import boolp.

Section state_monad_transformer.

Local Obligation Tactic := idtac.

Variables (S : Type) (M : monad).

Definition MS := fun A => S -> M (A * S)%type.

Definition retS A (a : A) : MS A :=
  fun (s : S) => Ret (a, s) : M (A * S)%type.

Definition bindS A B (m : MS A) f := (fun s => m s >>= uncurry f) : MS B.

Program Definition estateMonadM : monad :=
  @Monad_of_ret_bind MS retS bindS _ _ _.
Next Obligation.
by move=> A B a f; rewrite /bindS funeqE => s; rewrite bindretf.
Qed.
Next Obligation.
move=> A m; rewrite /bindS funeqE => s.
rewrite -[in RHS](bindmret (m s)); by bind_ext; case.
Qed.
Next Obligation.
move=> A B C m f g; rewrite /bindS funeqE => s.
by rewrite bindA; bind_ext; case.
Qed.

Definition liftS A (m : M A) : estateMonadM A :=
  fun s => @Bind M _ _ m (fun x => @Ret M _ (x, s)).

Program Definition stateMonadM : monadM M estateMonadM :=
  @monadM.mk _ _ liftS _ _.
Next Obligation.
by move=> A a; rewrite /liftS funeqE => s; rewrite bindretf.
Qed.
Next Obligation.
move=> A B m f; rewrite /liftS funeqE => s.
rewrite [in RHS]/Bind [in RHS]/Join /= /Monad_of_ret_bind.join /= /bindS !bindA.
bind_ext => a; by rewrite !bindretf.
Qed.

End state_monad_transformer.

Definition statemonad_transformer S : monadT :=
  @MonadT.mk (estateMonadM S) (@retS S) (@bindS S) (@stateMonadM S).

Section exception_monad_transformer.

Local Obligation Tactic := idtac.

Variables (Z : Type) (* the type of exceptions *) (M : monad).

Definition MX := fun X => M (Z + X)%type.

Definition retX X x : MX X := Ret (inr x).

Definition bindX X Y (t : MX X) (f : X -> MX Y) : MX Y :=
  t >>= fun c => match c with inl z => Ret (inl z) | inr x => f x end.

Program Definition eexceptionMonadM : monad :=
  @Monad_of_ret_bind MX retX bindX _ _ _.
Next Obligation. by move=> A B a f; rewrite /bindX bindretf. Qed.
Next Obligation.
move=> A m; rewrite /bindX -[in RHS](bindmret m); by bind_ext; case.
Qed.
Next Obligation.
move=> A B C m f g; rewrite /bindX bindA; bind_ext; case => //.
by move=> z; rewrite bindretf.
Qed.

Definition liftX X (m : M X) : eexceptionMonadM X := @Bind M _ _ m (fun x => @Ret eexceptionMonadM _ x).

Program Definition exceptionMonadM : monadM M eexceptionMonadM :=
  @monadM.mk _ _ liftX _ _.
Next Obligation. by move=> A a; rewrite /liftX bindretf. Qed.
Next Obligation.
move=> A B m f; rewrite /liftX [in RHS]/Bind [in RHS]/Join /=.
rewrite  /Monad_of_ret_bind.join /= /bindX !bindA.
bind_ext => a; by rewrite !bindretf.
Qed.

End exception_monad_transformer.

Definition exceptionmonad_transformer Z : monadT :=
  @MonadT.mk (eexceptionMonadM Z) (@retX Z) (@bindX Z) (@exceptionMonadM Z).

Section continuation_monad_tranformer.

Local Obligation Tactic := idtac.

Variables (r : Type)  (M : monad).

Definition MC : Type -> Type := fun A => (A -> M r) -> M r %type.

Definition retC A (a : A) : MC A :=
  fun cont => cont a.

Definition bindC A B (m : MC A) f : MC B :=
  fun cont => m (f^~ cont).

Program Definition econtMonadM : monad :=
  @Monad_of_ret_bind MC retC bindC _ _ _.
Next Obligation. by []. Qed.
Next Obligation. by []. Qed.
Next Obligation. by []. Qed.

Definition liftC A (x : M A) : econtMonadM A :=
  fun cont => x >>= cont.

Program Definition contMonadM : monadM M econtMonadM  :=
  @monadM.mk _ _ liftC  _ _.
Next Obligation.
move => A a.
rewrite /liftC funeqE => cont.
by rewrite !bindretf.
Qed.
Next Obligation.
move => A B m f.
rewrite /liftC funeqE => cont.
by rewrite !bindA.
Qed.

End continuation_monad_tranformer.

Definition continuationmonad_transformer R : monadT :=
  @MonadT.mk (econtMonadM R) (@retC R) (@bindC R) (@contMonadM R).

Let CMT := fun R M => @continuationmonad_transformer R M.

Definition callCC R M A B (f : (A -> CMT R M B) -> CMT R M A) : CMT R M A :=
  fun cont => f (fun x _ => cont x) cont.

Definition break (m : monad) : CMT unit m unit := fun _ => Ret tt.

Definition forLoop (m : monad) (items : list nat) (body : nat -> CMT unit m unit) : m unit :=
  foldr
    (fun x next => (body x) (fun _ => next))
    (Ret tt)
    items.

From monae Require Import monad_model state_monad.
(* From monae Require Import state_monad. *)

Definition ms : stateMonad nat := ModelState.state nat.

Definition exLoop : ms unit :=
  forLoop (iota 0 100) (fun i => if i > 10 then
                            @break _
                          else
                            liftC (Get >>= (fun z => Put (z + i)))).

Fail Definition goto :=
  callCC (fun out => let fn := out fn in retC fn).

Section foldM.
Variables (M : monad) (T R : Type) (f : R -> T -> M R).
Fixpoint foldM z s : M _ := if s is x :: s' then f z x >>= (fun y => foldM y s') else (Ret z).
End foldM.

Definition sumTilNothing' (m : monad) (break : _) (acc : nat) (x : option nat) : m nat :=
  if x is Some x then Ret (x + acc) else break acc.

Definition sumTilNothing (xs : seq (option nat)) : contM nat nat :=
  callcc (fun break : nat -> contM nat nat => foldM (sumTilNothing' break) 0 xs).

Compute (sumTilNothing [:: Some 2; Some 6; None; Some 4]).
  
Record operation (E : functor) (M : monad) := mkOperation {
  op : E \O M ~> M ;
  Hop : naturalP (E \O M) M op }.

Section get_functor.
Variable S : Type.
Definition get_act_obj X := S -> X.
Definition get_act_mor X Y (f : X -> Y) (t : get_act_obj X) : get_act_obj Y := fun s => f (t s).
Program Definition get_fun := Functor.Pack (@Functor.Class get_act_obj get_act_mor _ _ ).
Next Obligation. by move=> A; rewrite /get_act_mor funeqE. Qed.
Next Obligation. by move=> A B C g h; rewrite /get_act_mor funeqE. Qed.
End get_functor.

(* TODO: move to monad_model *)

Definition get_op S A (k : S -> ModelMonad.acto S A) : ModelMonad.acto S A :=
  fun s => k s s.

Program Definition get_operation S : operation (get_fun S) (ModelMonad.state S) :=
  @mkOperation _ _ (@get_op S) _.
Next Obligation.
move=> A B h; rewrite funeqE => /= m /=.
rewrite funeqE => s.
by rewrite FCompE Monad_of_ret_bind.fmapE.
Qed.

Goal forall S, @ModelState.get S = @get_op S S (@Ret (ModelMonad.state S) S).
Proof. by []. Qed.

