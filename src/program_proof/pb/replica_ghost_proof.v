From Perennial.program_proof Require Import grove_prelude.
From Goose.github_com.mit_pdos.gokv Require Import pb.
From Perennial.program_proof.pb Require Export replica_ghost_defns.
From Perennial.Helpers Require Import ListSolver.

#[global]
Hint Unfold log_po : list.

Section replica_ghost_proof.

Context `{!heapGS Σ}.
Context `{!urpcregG Σ}.
Context `{!pb_ghostG Σ}.
Implicit Type γ:pb_names.

(* accept a new log *)
Lemma append_new_ghost {rid} γ r (newCn:u64) newLog :
  int.Z r.(cn) ≤ int.Z newCn →
  int.Z r.(cn) < int.Z newCn ∨ length r.(opLog) ≤ length newLog →
  "Hown" ∷ own_Replica_ghost rid γ r ∗
  "#HnewProp" ∷ proposal_lb_fancy γ newCn newLog
  ={⊤}=∗
  own_Replica_ghost rid γ (mkReplica newLog newCn) ∗
  accepted_lb γ newCn rid newLog.
Proof.
  intros Hfresh Hnew.
  iNamed 1.
  iNamed "Hown".
  assert (int.Z r.(cn) < int.Z newCn ∨ int.Z r.(cn) = int.Z newCn) as [HnewCn|HoldCn] by word.
  { (* brand new cn *)
    iDestruct (big_sepS_elem_of_acc_impl newCn with "HacceptedUnused") as "[HH HacceptedUnused]".
    { set_solver. }
    iClear "Haccepted".
    iDestruct "HH" as "[%Hbad|Haccepted]".
    { exfalso. word. }
    iMod (accepted_update newLog with "Haccepted") as "Haccepted".
    { list_solver. }
    iDestruct (accepted_witness with "Haccepted") as "#$".
    iFrame "Haccepted HnewProp".
    iApply "HacceptedUnused".
    { (* prove impl: we have accepted_ptstos past newCn, since newCn > r.(cn) *)
      iModIntro.
      iIntros (???) "[%Hineq|$]".
      iLeft.
      iPureIntro.
      simpl.
      word.
    }
    { (* Prove that we don't need the element we accessed *)
      simpl.
      by iLeft.
    }
  }
  { (* same cn, but bigger log *)
    assert (r.(cn) = newCn) as HsameCn.
    { word. }
    rewrite HsameCn.
    iDestruct (proposal_lb_fancy_comparable with "Hproposal_lb HnewProp") as %[Hcomp|Hcomp].
    { (* new log bigger *)
      iMod (accepted_update newLog with "Haccepted") as "Haccepted".
      { done. }
      iDestruct (accepted_witness with "Haccepted") as "#$".
      by iFrame "∗ HnewProp".
    }
    { (* new log the same as before *)
      destruct Hnew as [Hbad|HnewLog].
      { exfalso; word. }
      assert (newLog = r.(opLog)) as ->.
      { list_solver. }
      iDestruct (accepted_witness with "Haccepted") as "#$".
      by iFrame "∗#".
    }
  }
Qed.

(*
  If we increase a replica's cn, want to know that we can keep its commitIdx
  unchanged. This is true because the proposal for cn' will need to have all of
  the committed entries from all previous cn's.
 *)
Lemma maintain_committer_ghost γ r c newCn newLog :
  int.Z r.(cn) ≤ int.Z newCn →
  int.Z r.(cn) < int.Z newCn ∨ length r.(opLog) ≤ length newLog →
  "#HoldProp" ∷ proposal_lb_fancy γ r.(cn) r.(opLog) ∗
  "#HnewProp" ∷ proposal_lb_fancy γ newCn newLog ∗
  "#Hownc" ∷ own_Committer_ghost γ r c
  ={⊤}=∗
  own_Committer_ghost γ (mkReplica newLog newCn) c.
Proof.
  intros HnotStale Hnew.
  iNamed 1.
  iNamed "Hownc".
  assert (int.Z r.(cn) = int.Z newCn ∨ int.Z r.(cn) < int.Z newCn) as [Hcase|Hcase] by word.
  { (* case: newCn == oldCn *)
    destruct Hnew as [Hbad|HlongerLog]; first word.
    unfold own_Committer_ghost.
    simpl.
    iSplitR ""; last first.
    { iPureIntro. word. }
    replace (newCn) with (r.(cn)) by word.
    iDestruct (proposal_lb_fancy_comparable with "HoldProp HnewProp") as %Hcomp.
    iApply (commit_lb_by_monotonic with "Hcommit_lb").
    { done. }
    destruct Hcomp as [Hlog|Hlog].
    * list_solver.
    * list_solver.
  }
  { (* case: newCn > oldCn *)
    iDestruct (oldConfMax_commit_lb_by with "HnewProp Hcommit_lb") as %HlogPrefix.
    { done. }
    unfold own_Committer_ghost.
    simpl.
    iModIntro.
    iSplitL "".
    {
      iApply (commit_lb_by_monotonic with "Hcommit_lb").
      { done. }
      (* B[:n] ⪯ A -∗ A[:n] ⪯ B[:n] *)
      list_solver.
    }
    {
      iPureIntro.
      (* A[:n] ⪯ B -∗ n ≤ length B *)
      list_solver.
    }
  }
Qed.

(* Same CN as before, and an old log; just get a witness that we already accepted *)
Lemma append_dup_ghost {rid} γ r (newCn:u64) newLog :
  int.Z r.(cn) = int.Z newCn ∧ length newLog ≤ length r.(opLog) →
  "Hown" ∷ own_Replica_ghost rid γ r ∗
  "#HnewProp" ∷ proposal_lb_fancy γ newCn newLog
  ={⊤}=∗
  own_Replica_ghost rid γ r ∗
  accepted_lb γ newCn rid newLog.
Proof.
  intros [Hre HstaleLog].
  assert (r.(cn) = newCn) as <- by word.
  iNamed 1.
  iNamed "Hown".
  iDestruct (accepted_witness with "Haccepted") as "#Hacc1".
  (* NOTE: idea: introduce a "comparable" predicate, and have some lemmas about that *)
  iDestruct (proposal_lb_fancy_comparable with "Hproposal_lb HnewProp") as %[Hcomp|Hcomp].
  { (* log must be equal *)
    replace (newLog) with (r.(opLog)); last first.
    { (* TODO: list_solver candidate *) admit. } (* len A ≤ len B ∧ B ⪯ A → B = A *)
    iDestruct (accepted_lb_monotonic with "Hacc1") as "$".
    { done. }
    by iFrame "∗#".
  }
  {
    iDestruct (accepted_lb_monotonic with "Hacc1") as "$".
    { done. }
    by iFrame "∗#".
  }
Admitted.

(* Increase commitIdx by getting a commit_lb_by witness from primary *)
Lemma commit_idx_update {rid} γ r log newCommitIdx :
  int.Z newCommitIdx ≤ length log →
  "Hown" ∷ own_Replica_ghost rid γ r ∗
  "#Hacc" ∷ accepted_lb γ r.(cn) rid log ∗
  "#Hcommit_lb" ∷ commit_lb_by γ r.(cn) (take (int.nat newCommitIdx) log)
  -∗
  own_Replica_ghost rid γ r ∗
  own_Committer_ghost γ r (mkCommitterExtra newCommitIdx).
Proof.
  (* argument: log ⪯ r.(log); (take n log) == (take n r.(log)); *)
  intros HcommitIdx.
  iNamed 1.
  iNamed "Hown".
  iDestruct (accepted_lb_le with "Haccepted Hacc") as "%HlogLe".
  replace (take (int.nat newCommitIdx) log)
          with (take (int.nat newCommitIdx) r.(opLog)); last first.
  {
    assert (int.nat newCommitIdx <= length log) by word.
    set (a:=int.nat newCommitIdx) in *.
    admit. (* TODO: list_solver candidate *)
  }
  iFrame "∗#".
  iPureIntro.
  simpl.
  list_solver.
Admitted.

Lemma primary_matchidx_lookup {rid} conf (i:u64) γ r p :
  conf !! int.nat i = Some rid →
  "#Hconf" ∷ config_ptsto γ r.(cn) conf ∗
  "HprimaryG" ∷ own_Primary_ghost γ r p
  -∗
  ⌜∃ (x:u64), p.(matchIdx) !! int.nat i = Some x⌝.
Proof.
  intros HconfLookup.
  iNamed 1.
  iNamed "HprimaryG".
  iDestruct (config_ptsto_agree with "Hconf HconfPtsto") as %->.
  iDestruct (big_sepL2_lookup_1_some with "HmatchIdxAccepted") as "$".
  done.
Qed.

Lemma primary_update_matchidx {rid} (i oldIdx:u64) γ r p newLog (newLogLen:u64) :
  p.(matchIdx) !! int.nat i = Some oldIdx →
  p.(conf) !! int.nat i = Some rid →
  length newLog = int.nat newLogLen →
  "HprimaryG" ∷ own_Primary_ghost γ r p ∗
  "#Hacc_lb" ∷ accepted_lb γ r.(cn) rid newLog ∗
  "#Hprop_lb" ∷ proposal_lb γ r.(cn) newLog
  -∗
  own_Primary_ghost γ r (mkPrimaryExtra
                           p.(conf)
                           (<[int.nat i:=newLogLen]> p.(matchIdx)) ).
Proof.
  intros HmatchIdxLookup HconfLookup Hlen.
  iNamed 1.
  iNamed "HprimaryG".
  iDestruct (proposal_lb_le with "HprimaryOwnsProposal Hprop_lb") as %HlogLe.
  unfold own_Primary_ghost.
  iFrame "∗#".
  iDestruct (big_sepL2_insert_acc with "HmatchIdxAccepted") as "[_ HH]".
  { done. }
  { done. }
  iSpecialize ("HH" $! rid).
  replace (<[int.nat i:=rid]> p.(conf)) with (p.(conf)); last first.
  { by rewrite list_insert_id. }
  iApply "HH".
  replace (take (int.nat newLogLen) r.(opLog)) with (newLog); last first.
  {
    admit. (* TODO: list_solver. candidate *)
  }
  iFrame "#".
Admitted.

Lemma primary_commit m γ r (p:PrimaryExtra) :
  m ∈ p.(matchIdx) →
  (∀ n, n ∈ p.(matchIdx) → int.Z m ≤ int.Z n) →
  int.Z m ≤ length r.(opLog) →
  pb_inv γ -∗
  proposal_lb_fancy γ r.(cn) r.(opLog) -∗
  own_Primary_ghost γ r p
  ={⊤}=∗
  own_Primary_ghost γ r p ∗
  own_Committer_ghost γ r (mkCommitterExtra m).
Proof.
  intros Hm Hmin HmLog.
  iIntros "#HpbInv #Hprop_lb".
  iNamed 1.
  iFrame "∗#".
  unfold own_Committer_ghost.
  simpl.
  iSplitR ""; last done.
  iMod (do_commit with "HpbInv [] []") as "$".
  { (* TODO: Use accepted_by_fancy. *) admit. }
  { unfold accepted_by.
    iExists _; iFrame "HconfPtsto".
    iIntros (rid Hrid).
    assert (exists i, p.(conf) !! i = Some rid) as [i HconfLookup].
    { by apply elem_of_list_lookup_1. }
    iDestruct (big_sepL2_lookup_1_some with "HmatchIdxAccepted") as %[n HmatchIdxLookup].
    { done. }
    iDestruct (big_sepL2_lookup_acc with "HmatchIdxAccepted") as "[Hacc _]".
    { done. }
    { done. }
    assert (int.Z m <= int.Z n).
    {
      apply Hmin.
      by eapply elem_of_list_lookup_2.
    }
    iApply (accepted_lb_monotonic with "Hacc").
    list_solver.
  }
  done.
Admitted.

End replica_ghost_proof.
