From Perennial.program_proof.mvcc Require Import txn_prelude.
From Perennial.program_proof.mvcc Require Import tuple_repr index_proof.

Section repr.
Context `{!heapGS Σ, !mvcc_ghostG Σ}.

(* TODO: [site_active_tids_half_auth γ sid (gset_to_gmap () (list_to_set tidsactiveL))] to remove [tidsactiveM] *)
Definition own_txnsite (txnsite : loc) (sid : u64) γ : iProp Σ := 
  (* FIXME: don't need [tidlast] anymore. *)
  ∃ (tidlast tidmin : u64) (tidsactive : Slice.t)
    (tidsactiveL : list u64) (tidsactiveM : gmap u64 unit),
    "Htidlast" ∷ txnsite ↦[TxnSite :: "tidLast"] #tidlast ∗
    "#Htslb" ∷ ts_lb γ (S (int.nat tidlast)) ∗
    "Hactive" ∷ txnsite ↦[TxnSite :: "tidsActive"] (to_val tidsactive) ∗
    "HactiveL" ∷ typed_slice.is_slice tidsactive uint64T 1 tidsactiveL ∗
    "HactiveAuth" ∷ site_active_tids_half_auth γ sid tidsactiveM ∗
    "%HactiveLM" ∷ ⌜(list_to_set tidsactiveL) = dom tidsactiveM⌝ ∗
    "%HactiveND" ∷ (⌜NoDup tidsactiveL⌝) ∗
    "HminAuth" ∷ site_min_tid_half_auth γ sid (int.nat tidmin) ∗
    "%HtidOrder" ∷ (⌜Forall (λ tid, int.Z tidmin ≤ int.Z tid ≤ int.Z tidlast) (tidlast :: tidsactiveL)⌝) ∗
    "%HtidFree" ∷ (∀ tid, ⌜int.Z tidlast < int.Z tid -> tid ∉ dom tidsactiveM⌝) ∗
    "_" ∷ True.

Definition is_txnsite (site : loc) (sid : u64) γ : iProp Σ := 
  ∃ (latch : loc),
    "#Hlatch" ∷ readonly (site ↦[TxnSite :: "latch"] #latch) ∗
    "#Hlock" ∷ is_lock mvccN #latch (own_txnsite site sid γ) ∗
    "_" ∷ True.

Definition own_txnmgr (txnmgr : loc) : iProp Σ := 
  ∃ (sidcur : u64),
    "Hsidcur" ∷ txnmgr ↦[TxnMgr :: "sidCur"] #sidcur ∗
    "%HsidcurB" ∷ ⌜(int.Z sidcur) < N_TXN_SITES⌝ ∗
    "_" ∷ True.

Definition is_txnmgr (txnmgr : loc) γ : iProp Σ := 
  ∃ (latch : loc) (sites : Slice.t) (idx gc : loc)
    (sitesL : list loc) (p : proph_id),
    "#Hlatch" ∷ readonly (txnmgr ↦[TxnMgr :: "latch"] #latch) ∗
    "#Hlock" ∷ is_lock mvccN #latch (own_txnmgr txnmgr) ∗
    "#Hidx" ∷ readonly (txnmgr ↦[TxnMgr :: "idx"] #idx) ∗
    "#HidxRI" ∷ is_index idx γ ∗
    "#Hgc" ∷ readonly (txnmgr ↦[TxnMgr :: "gc"] #gc) ∗
    "#Hsites" ∷ readonly (txnmgr ↦[TxnMgr :: "sites"] (to_val sites)) ∗
    "#HsitesS" ∷ readonly (is_slice_small sites ptrT 1 (to_val <$> sitesL)) ∗
    "%HsitesLen" ∷ ⌜Z.of_nat (length sitesL) = N_TXN_SITES⌝ ∗
    "#HsitesRP" ∷ ([∗ list] sid ↦ site ∈ sitesL, is_txnsite site sid γ) ∗
    "#Hp" ∷ readonly (txnmgr ↦[TxnMgr :: "p"] #p) ∗
    "#Hinvgc" ∷ mvcc_inv_gc γ ∗
    "#Hinvsst" ∷ mvcc_inv_sst γ p ∗
    "_" ∷ True.

End repr.

#[global]
Hint Extern 1 (environments.envs_entails _ (own_txnsite _ _ _)) => unfold own_txnsite : core.
#[global]
Hint Extern 1 (environments.envs_entails _ (own_txnmgr _)) => unfold own_txnmgr : core.
#[global]
Hint Extern 1 (environments.envs_entails _ (is_txnmgr _ _)) => unfold is_txnmgr : core.
