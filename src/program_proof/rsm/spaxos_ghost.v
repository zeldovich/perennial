(**
 * Ghost state definitions, type class instances, and rules.
 *)
From Perennial.program_proof Require Import spaxos_top.
From Perennial.base_logic Require Import ghost_map mono_nat.
From iris.algebra Require Import mono_nat mono_list gmap_view gset.

Class spaxos_ghostG (Σ : gFunctors).

Record spaxos_names := {}.

Section consensus.
  Context `{!spaxos_ghostG Σ}.
  (* TODO: remove this once we have real defintions for resources. *)
  Implicit Type (γ : spaxos_names).

  (* Definitions. *)
  Definition own_consensus γ (c : consensus) : iProp Σ.
  Admitted.

  Definition is_chosen_consensus γ v : iProp Σ :=
    own_consensus γ (Chosen v).

  (* Type class instances. *)
  #[global]
  Instance is_chosen_consensus_persistent γ v :
    Persistent (is_chosen_consensus γ v).
  Admitted.
  
  (* Rules. *)
  Lemma consensus_update {γ} v :
    own_consensus γ Free ==∗
    own_consensus γ (Chosen v).
  Admitted.

  Lemma consensus_witness {γ v} :
    own_consensus γ (Chosen v) -∗
    is_chosen_consensus γ v.
  Admitted.

  Lemma consensus_agree {γ} v1 v2 :
    is_chosen_consensus γ v1 -∗
    is_chosen_consensus γ v2 -∗
    ⌜v1 = v2⌝.
  Admitted.
End consensus.

Section proposal.
  Context `{!spaxos_ghostG Σ}.
  (* TODO: remove this once we have real defintions for resources. *)
  Implicit Type (γ : spaxos_names).

  (* Definitions. *)
  Definition is_proposal γ (n : nat) (v : string) : iProp Σ.
  Admitted.

  Definition own_proposals γ (ps : gmap nat string) : iProp Σ.
  Admitted.
  
  (* Type class instances. *)
  #[global]
  Instance is_proposal_persistent γ n v :
    Persistent (is_proposal γ n v).
  Admitted.

  (* Rules. *)
  Lemma proposals_insert {γ} ps n v :
    ps !! n = None ->
    own_proposals γ ps ==∗
    own_proposals γ (<[n := v]> ps) ∗ is_proposal γ n v.
  Admitted.
End proposal.

Section ballot.
  Context `{!spaxos_ghostG Σ}.
  (* TODO: remove this once we have real defintions for resources. *)
  Implicit Type (γ : spaxos_names).

  (* Definitions. *)
  Definition own_ballot γ (x : nat) (b : ballot) : iProp Σ.
  Admitted.

  Definition is_ballot_lb γ (x : nat) (b : ballot) : iProp Σ.
  Admitted.

  Definition own_ballots γ (bs : gmap nat ballot) : iProp Σ.
  Admitted.

  (* Type class instances. *)
  #[global]
  Instance is_ballot_lb_persistent γ x b :
    Persistent (is_ballot_lb γ x b).
  Admitted.

  (* Rules. *)
  Lemma ballot_update {γ} bs x b b' :
    prefix b b' ->
    own_ballot γ x b -∗
    own_ballots γ bs ==∗
    own_ballot γ x b' ∗ own_ballots γ (<[x := b']> bs).
  Admitted.
End ballot.
