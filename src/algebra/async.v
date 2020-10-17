From stdpp Require Import countable.
From iris.algebra Require Import mlist gmap_view.
From iris.base_logic Require Import lib.iprop.
From iris.proofmode Require Import tactics.
From Perennial.algebra Require Import log_heap.

Set Default Proof Using "Type".

Class asyncG Σ (K V: Type) `{Countable K, EqDecision V} := {
  async_listG :> fmlistG (gmap K V) Σ;
  async_mapG :> inG Σ (gmap_viewR K natO);
}.

(** We need two ghost names. *)
Record async_gname := {
  async_list : gname;
  async_map : gname;
}.

Section async.
Context {K V: Type} `{Countable K, EqDecision V, asyncG Σ K V}.

Implicit Types (γ:async_gname) (k:K) (v:V) (i:nat) (σ: gmap K V) (σs: async (gmap K V)) (last: gmap K nat).

Definition lookup_async σs i k : option V :=
  σ ← possible σs !! i; σ !! k.


Local Definition is_last σs k i : Prop :=
  ∃ v, lookup_async σs i k = Some v ∧
    ∀ i', i ≤ i' → i' < length (possible σs) → lookup_async σs i' k = Some v.
Local Definition own_last_auth γ σs : iProp Σ :=
  ∃ last, ⌜map_Forall (is_last σs) last⌝ ∗ own γ.(async_map) (gmap_view_auth last).
Local Definition own_last_frag γ k i : iProp Σ :=
  own γ.(async_map) (gmap_view_frag k (DfracOwn 1) i).

(* The possible states in [σs] are tracked in a regular append-only list.
Additionally, there is a way to control which was the last transaction that changed
a certain key, which ensures that the key stayed unchanged since then.

 Durability is orthogonal to this library: separately from the async we know
 that some index is durable, which guarantees that facts about that index and
 below can be carried across a crash. *)
Definition async_ctx γ σs : iProp Σ :=
   own_last_auth γ σs ∗
      (* We also have the [lb] in here to avoid some update modalities below. *)
      fmlist γ.(async_list) 1 (possible σs) ∗ fmlist_lb γ.(async_list) (possible σs).

(* ephemeral_txn_val owns only a single point in the ephemeral transactions.
It is persistent. *)
Definition ephemeral_txn_val γ (i:nat) (k: K) (v: V) : iProp Σ :=
  ∃ σ, ⌜σ !! k = Some v⌝ ∗ fmlist_idx γ.(async_list) i σ.

(* ephemeral_val_from owns ephemeral transactions from i onward (including
future transactions); this is what makes it possible to use ephemeral
maps-to facts to append a new gmap with those addresses updated (see
[map_update_predicate] for the kind of thing we should be able to do) *)
Definition ephemeral_val_from γ (i:nat) (k: K) (v: V) : iProp Σ :=
  ephemeral_txn_val γ i k v ∗ own_last_frag γ k i.

(* exactly like [ephemeral_txn_val] except owning a half-open range of
transactions [lo, hi) *)
Definition ephemeral_txn_val_range γ (lo hi:nat) (k: K) (v: V): iProp Σ :=
  [∗ list] i ∈ seq lo (hi-lo), ephemeral_txn_val γ i k v.

Global Instance async_ctx_timeless γ σs : Timeless (async_ctx γ σs).
Proof. apply _. Qed.

(* Just shift the "last" transaction i without changing the value. *)
Local Lemma own_last_shift γ σs k i i' :
  (i ≤ i')%nat →
  (i' < length (possible σs))%nat →
  own_last_auth γ σs -∗
  own_last_frag  γ k i ==∗
  own_last_auth γ σs ∗ own_last_frag γ k i'.
Proof.
  iIntros (Hle Hi') "Halast Hflast".
  iDestruct "Halast" as (last Hlast) "Hmap".
  iDestruct (own_valid_2 with "Hmap Hflast") as %[_ Hk]%gmap_view_both_valid_L.
  iMod (own_update_2 with "Hmap Hflast") as "[Hmap Hflast]".
  { apply (gmap_view_update _ k i i'). }
  iModIntro. iFrame "Hflast".
  iExists _. iFrame. iPureIntro. intros k' j.
  destruct (decide (k=k')) as [->|Hne].
  - rewrite lookup_insert=>[=<-]. destruct (Hlast _ _ Hk) as (v & Hv & Htail).
    exists v. split.
    + apply Htail; lia.
    + intros i'' Hi''. apply Htail. lia.
  - rewrite lookup_insert_ne // => Hk'.
    destruct (Hlast _ _ Hk') as (v & Hv & Htail).
    exists v. done.
Qed.

Local Lemma own_last_put γ σs :
  own_last_auth γ σs -∗ own_last_auth γ (async_put (latest σs) σs).
Proof.
  iIntros "Hlast". iDestruct "Hlast" as (last Hlast) "Hmap".
  iExists last. iFrame. iPureIntro.
  intros k i Hk. destruct (Hlast _ _ Hk) as (v & Hv & Htail).
  assert (i < length (possible σs)).
  { apply lookup_lt_is_Some_1. rewrite /lookup_async in Hv.
    destruct (possible σs !! i); last done. eauto. }
  exists v. split.
  - rewrite /lookup_async possible_async_put lookup_app_l //.
  - intros i' Hle Hlen.
    rewrite /lookup_async possible_async_put.
    destruct (decide (i' = length (possible σs))) as [->|Hne].
    + rewrite list_lookup_middle //.
      rewrite -lookup_possible_latest'.
      assert (length (possible σs) > 0).
      { rewrite /possible app_length /=. lia. }
      eapply Htail; lia.
    + rewrite length_possible_async_put in Hlen.
      rewrite lookup_app_l; last lia.
      apply Htail; lia.
Qed.

(* As far as just [own_last] is concerned, we can change the value of the
last transaction. *)
Local Lemma own_last_update γ σs k v' m i :
  own_last_auth γ (async_put m σs) -∗
  own_last_frag γ k i ==∗
  own_last_auth γ (async_put (<[k:=v']> m) σs) ∗
    own_last_frag γ k (S (length (possible σs)) - 1).
Proof. Admitted.

Theorem ephemeral_txn_val_range_acc γ lo hi k v i :
  (lo ≤ i < hi)%nat →
  ephemeral_txn_val_range γ lo hi k v -∗
  (* does not return the range under the assumption we make these persistent *)
  ephemeral_txn_val γ i k v.
Proof.
  iIntros (Hbound) "Hrange".
  rewrite /ephemeral_txn_val_range.
  assert (seq lo (hi - lo)%nat !! (i - lo)%nat = Some i).
  { apply lookup_seq; lia. }
  iDestruct (big_sepL_lookup with "Hrange") as "$"; eauto.
Qed.

Theorem ephemeral_val_from_in_bounds γ σs i k v :
  async_ctx γ σs -∗
  ephemeral_val_from γ i k v -∗
  (* if equal, only owns the new transactions and no current ones *)
  ⌜i < length (possible σs)⌝%nat.
Proof.
  iIntros "(Halast & Halist & _) [Hval Hflast]".
  iDestruct "Halast" as (last Hlast) "Hmap".
  iDestruct "Hval" as (σ Hσ) "Hflist".
  iDestruct (fmlist_idx_agree_2 with "Halist Hflist") as %Hi.
  iPureIntro.
  apply lookup_lt_is_Some. rewrite Hi. eauto.
Qed.

Theorem ephemeral_txn_val_lookup γ σs i k v :
  async_ctx γ σs -∗
  ephemeral_txn_val γ i k v -∗
  ⌜lookup_async σs i k = Some v⌝.
Proof.
  iIntros "(Halast & Halist & _) Hval".
  iDestruct "Halast" as (last Hlast) "Hmap".
  iDestruct "Hval" as (σ Hσ) "Hflist".
  iDestruct (fmlist_idx_agree_2 with "Halist Hflist") as %Hi.
  rewrite /lookup_async Hi /=. done.
Qed.

Theorem ephemeral_lookup_txn_val γ σs i k v :
  lookup_async σs i k = Some v →
  async_ctx γ σs -∗
  ephemeral_txn_val γ i k v.
Proof.
  rewrite /lookup_async /ephemeral_txn_val.
  iIntros (Hlookup) "(_ & _ & Hflist)".
  destruct (possible σs !! i) as [σ|] eqn:Hσ; last done.
  simpl in Hlookup.
  iExists _. iSplit; first done.
  iApply fmlist_lb_to_idx; done.
Qed.

(** All transactions since [i] have the value given by [ephemeral_val_from γ i]. *)
Theorem ephemeral_val_from_val γ σs i i' k v :
  (i ≤ i') →
  (i' < length (possible σs))%nat →
  async_ctx γ σs -∗
  ephemeral_val_from γ i k v -∗
  ephemeral_txn_val γ i' k v.
Proof.
  iIntros (??) "Hauth [Hval Hlast]".
  iDestruct (ephemeral_txn_val_lookup with "Hauth Hval") as %Hlookup.
  iClear "Hval".
  iDestruct "Hauth" as "(Halast & Halist & Hflist)".
  iDestruct "Halast" as (last Hlast) "Hmap".
  iDestruct (own_valid_2 with "Hmap Hlast") as %[_ Hmap]%gmap_view_both_valid_L.
  destruct (Hlast _ _ Hmap) as (v' & Hlookup' & Htail).
  rewrite Hlookup in Hlookup'. injection Hlookup' as [=<-].
  iApply ephemeral_lookup_txn_val; last first.
  - rewrite /async_ctx. iFrame. iExists last. iFrame. done.
  - apply Htail; done.
Qed.

(** Move the "from" resource from i to i', and obtain a
[ephemeral_txn_val_range] for the skipped range and including [i']. *)
Theorem ephemeral_val_from_split i' γ i k v σs :
  (i ≤ i')%nat →
  (i' < length (possible σs))%nat →
  async_ctx γ σs -∗
  ephemeral_val_from γ i k v ==∗
  async_ctx γ σs ∗ ephemeral_txn_val_range γ i (S i') k v ∗ ephemeral_val_from γ i' k v.
Proof.
  iIntros (Hle Hi') "Hauth Hfromi".

  (* Get some things from [async_ctx] before we take it apart. *)
  iAssert (ephemeral_txn_val_range γ i (S i') k v) with "[Hauth Hfromi]" as "#$".
  { rewrite /ephemeral_txn_val_range. iInduction Hle as [|i' Hle] "IH".
    - assert (S i-i = 1) as -> by lia. rewrite big_sepL_singleton.
      iDestruct "Hfromi" as "[$ _]".
    - assert (S (S i') - i = S (S i'-i)) as -> by lia. rewrite seq_S_end_app.
      rewrite big_sepL_app. iSplit.
      { iApply ("IH" with "[] Hauth Hfromi"). iPureIntro. lia. }
      rewrite big_sepL_singleton.
      iApply (ephemeral_val_from_val with "Hauth Hfromi"); lia. }
  iAssert (ephemeral_txn_val γ i' k v) with "[Hauth Hfromi]" as "#Hvali'".
  { iApply (ephemeral_val_from_val with "Hauth Hfromi"); lia. }

  iDestruct "Hauth" as "(Halast & Halist & Hflist)".
  iDestruct "Hfromi" as "[#Hvali Hlast]".
  iMod (own_last_shift with "Halast Hlast") as "[$ $]"; [done..|].
  by iFrame "∗#".
Qed.

(* TODO: we really need a strong init that also creates ephemeral_val_from for
every address in the domain; this is where it's useful to know that the async
has maps with the same domain *)
Theorem async_ctx_init σs:
  ⊢ |==> ∃ γ, async_ctx γ σs.
Proof.
  iMod (fmlist_alloc (possible σs)) as (γlist) "Hlist".
  iMod (fmlist_get_lb with "Hlist") as "[Halist Hflist]".
  set (last := (λ _, length (pending σs)) <$> (latest σs)).
  iMod (own_alloc (gmap_view_auth last)) as (γmap) "Hmap".
  { apply gmap_view_auth_valid. }
  iModIntro. iExists (Build_async_gname γlist γmap).
  rewrite /async_ctx /=. iFrame. iExists last. iFrame.
  iPureIntro. subst last. intros k i.
  rewrite lookup_fmap. destruct (latest σs !! k) as [v|] eqn:Hlatest; last done.
  simpl=>[=<-]. exists v. split.
  - rewrite /lookup_async lookup_possible_latest /=. done.
  - intros i'. rewrite length_possible_pending=>??.
    assert (i' = length (pending σs)) as -> by lia.
    rewrite /lookup_async lookup_possible_latest /=. done.
Qed.

Theorem async_update_map m' γ σs m0 :
  dom (gset _) m' = dom (gset _) m0 →
  async_ctx γ σs -∗
  ([∗ map] k↦v ∈ m0, ephemeral_val_from γ (length (possible σs) - 1) k v) -∗
  |==> let σs' := (async_put (m' ∪ latest σs) σs) in
     async_ctx γ σs' ∗
       ([∗ map] k↦v ∈ m', ephemeral_val_from γ (length (possible σs') - 1) k v).
       (* We could also make this [length (possible σs)]; not sure what is more useful. *)
Proof.
  iIntros (Hdom) "Hctx Hm".
  iDestruct "Hctx" as "(Halast & Halist & _)".
  rewrite /async_ctx.
  iMod (fmlist_update with "Halist") as "[$ #Hflist]".
  { apply prefix_app_r. reflexivity. }
  iFrame "Hflist".

  (* Take care of the [ephemeral_txn_val] part of the goal. *)
  rewrite /ephemeral_val_from [(own_last_auth _ _ ∗ _)%I]comm.
  iEval (rewrite big_sepM_sep -assoc). iSplitR.
  { iApply big_sepM_forall.
    iIntros "!>" (k v Hm').
    iExists (m' ∪ latest σs). iSplit.
    - iPureIntro. rewrite lookup_union Hm'.
      destruct (latest σs !! k); done.
    - iApply fmlist_lb_to_idx; last done.
      rewrite lookup_possible_latest'. done. }
  iClear "Hflist".

  iDestruct (own_last_put with "Halast") as "Halast".
  rewrite length_possible_async_put.
  iInduction m' as [|a v m] "IH" using map_ind forall (m0 Hdom).
  - assert (m0 = ∅) as ->.
    { apply dom_empty_inv. rewrite -Hdom dom_empty. done. }
    rewrite !big_sepM_empty. rewrite !left_id. by iFrame.
  - rewrite big_sepM_insert //.
    assert (is_Some (m0 !! a)) as [v0 Hv0].
    { apply elem_of_dom. rewrite -Hdom dom_insert. set_solver+. }
    iDestruct (big_sepM_delete with "Hm") as "[[_ Hlast] Hm]"; first done.
    iMod ("IH" with "[] Hm Halast") as "[$ Halast]".
    { iPureIntro. rewrite dom_delete_L -Hdom dom_insert_L.
      assert (a ∉ dom (gset K) m) as Hnotm.
      { apply not_elem_of_dom. done. }
      set_solver +Hnotm. }
    iClear "IH".
    iMod (own_last_update with "Halast Hlast") as "[Halast Hlast]".
    rewrite insert_union_l /ephemeral_val_from. iFrame. done.
Qed.

(* this splits off an [ephemeral_val_from] at exactly the last transaction *)
Theorem async_ctx_ephemeral_val_from_split γ σs i k v :
  async_ctx γ σs -∗
  ephemeral_val_from γ i k v ==∗
  async_ctx γ σs ∗ ephemeral_txn_val_range γ i (length (possible σs)) k v ∗
    ephemeral_val_from γ (length (possible σs) - 1) k v.
Proof.
  iIntros "Hctx Hi+".
  iDestruct (ephemeral_val_from_in_bounds with "Hctx Hi+") as %Hinbounds.
  iMod (ephemeral_val_from_split (length (possible σs) - 1) with "Hctx Hi+")
    as "(Hctx & Hold & H+)"; [lia..|].
  assert (S (length (possible σs) - 1) = length (possible σs)) as -> by lia.
  by iFrame.
Qed.

(* this splits off several [ephemeral_val_from] all at the last transaction *)
Theorem async_ctx_ephemeral_val_from_map_split γ σs i m :
  async_ctx γ σs -∗
  big_opM bi_sep (ephemeral_val_from γ i) m ==∗
  async_ctx γ σs ∗ big_opM bi_sep (ephemeral_txn_val_range γ i (length (possible σs))) m ∗
  big_opM bi_sep (ephemeral_val_from γ (length (possible σs) - 1)) m.
Proof.
  iIntros "Hctx Hm".
  iInduction m as [|a v m] "IH" using map_ind.
  - rewrite !big_sepM_empty.
    by iFrame.
  - iDestruct (big_sepM_insert with "Hm") as "[Hi Hm]"; auto.
    iMod (async_ctx_ephemeral_val_from_split with "Hctx Hi") as "(Hctx&Hrange&H+)".
    iMod ("IH" with "Hctx Hm") as "(Hctx&Hmrange&Hm+)".
    iFrame.
    rewrite !big_sepM_insert //; by iFrame.
Qed.

End async.
