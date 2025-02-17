From Perennial.program_proof Require Import grove_prelude.
From Goose.github_com.mit_pdos.gokv Require mpaxos.
From Perennial.program_proof.grove_shared Require Import urpc_proof urpc_spec.
From Perennial.goose_lang.lib Require Import waitgroup.
From iris.base_logic Require Export lib.ghost_var mono_nat.
From iris.algebra Require Import dfrac_agree mono_list.
From Perennial.goose_lang Require Import crash_borrow.
From Perennial.program_proof Require Import marshal_stateless_proof.
From Perennial.program_proof.mpaxos Require Export definitions.

Section enternewepoch_proof.

Context `{!heapGS Σ}.
Context {mp_record:MPRecord}.
Notation OpType := (mp_OpType mp_record).
Notation has_op_encoding := (mp_has_op_encoding mp_record).
Notation next_state := (mp_next_state mp_record).
Notation compute_reply := (mp_compute_reply mp_record).
Notation is_Server := (is_Server (mp_record:=mp_record)).
Notation enterNewEpoch_core_spec := (enterNewEpoch_core_spec).
Notation is_singleClerk := (is_singleClerk (mp_record:=mp_record)).

Context (conf:list mp_server_names).
Context `{!mpG Σ}.

Lemma wp_singleClerk__enterNewEpoch ck γ γsrv args_ptr args q :
  {{{
        "#His_ck" ∷ is_singleClerk conf ck γ γsrv ∗
        "Hargs" ∷ enterNewEpochArgs.own args_ptr args q
  }}}
    singleClerk__enterNewEpoch #ck #args_ptr
  {{{
        reply_ptr reply, RET #reply_ptr; enterNewEpochReply.own reply_ptr reply 1 ∗
        if (decide (reply.(enterNewEpochReply.err) = (U64 0))) then
          enterNewEpoch_post conf γ γsrv reply args.(enterNewEpochArgs.epoch)
        else
          True
  }}}.
Proof.
  iIntros (Φ) "Hpre HΦ".
  iNamed "Hpre".
  wp_call.
  wp_apply (enterNewEpochArgs.wp_Encode with "Hargs").
  iIntros (enc enc_sl) "[%Hargs_enc Hsl]".
  wp_pures.
  wp_apply (wp_ref_of_zero).
  { done. }
  iIntros (rep_ptr) "Hrep".
  wp_pures.
  iNamed "His_ck".
  wp_loadField.
  iDestruct (own_slice_to_small with "Hsl") as "Hsl".
  iApply (wp_frame_wand with "[HΦ]").
  { iNamedAccu. }
  wp_apply (wp_ReconnectingClient__Call2 with "Hcl_rpc [] Hsl Hrep").
  {
    unfold is_mpaxos_host.
    iNamed "Hsrv".
    iFrame "#".
  }
  { (* Successful RPC *)
    iModIntro.
    iNext.
    unfold enterNewEpoch_spec.
    iExists _.
    iSplitR; first done.
    simpl.
    iSplit.
    {
      iIntros (?) "Hpost".
      iIntros (?) "%Henc_reply Hsl".
      iIntros (?) "Hrep Hrep_sl".
      wp_pures.
      wp_load.
      rewrite Henc_reply.
      wp_apply (enterNewEpochReply.wp_Decode with "[$Hrep_sl]").
      { done. }
      iIntros (reply_ptr) "Hreply".
      iIntros "HΦ".
      iApply "HΦ".
      iFrame "∗".
      destruct (decide _).
      { iFrame. }
      done.
    }
    { (* Apply failed for some reason, e.g. node is not primary *)
      iIntros (? Hreply_err).
      iIntros (?) "%Henc_reply Hsl".
      iIntros (?) "Hrep Hrep_sl".
      wp_pures.
      wp_load.
      rewrite Henc_reply.
      wp_apply (enterNewEpochReply.wp_Decode with "[$Hrep_sl]").
      { done. }
      iIntros (reply_ptr) "Hreply".
      iIntros "HΦ".
      iApply "HΦ".
      iFrame "∗".
      destruct (decide _).
      { exfalso. done. }
      { done. }
    }
  }
  { (* RPC error *)
    iIntros.
    wp_pures.
    destruct (bool_decide _) as [] eqn:X.
    {
      exfalso.
      apply bool_decide_eq_true in X.
      naive_solver.
    }
    wp_pures.

    iDestruct (own_slice_small_nil byteT 1 Slice.nil) as "Hsl".
    { done. }
    iMod (readonly_alloc_1 with "Hsl") as "#Hsl2".

    wp_apply (wp_allocStruct).
    { repeat econstructor. eauto. }
    iIntros (reply_ptr) "Hreply".
    iNamed 1.
    iApply "HΦ".
    iDestruct (struct_fields_split with "Hreply") as "HH".
    iNamed "HH".

    iSplitL.
    {
      iExists _.
      instantiate (1:=enterNewEpochReply.mkC _ _ _ _).
      simpl.
      replace (zero_val (slice.T byteT)) with (slice_val (Slice.nil)) by done.
      iFrame "∗#".
    }
    simpl.
    done.
  }
Qed.

Lemma wp_Server__enterNewEpoch (s:loc) (args_ptr reply_ptr:loc) γ γsrv args init_reply Φ Ψ :
  is_Server conf s γ γsrv -∗
  enterNewEpochArgs.own args_ptr args 1 -∗
  enterNewEpochReply.own reply_ptr init_reply 1 -∗
  (∀ reply, Ψ reply -∗ enterNewEpochReply.own reply_ptr reply 1 -∗ Φ #()) -∗
  enterNewEpoch_core_spec conf γ γsrv args Ψ -∗
  WP mpaxos.Server__enterNewEpoch #s #args_ptr #reply_ptr {{ Φ }}
.
Proof.
  iIntros "#HisSrv Hpre Hreply HΦ HΨ".
  iNamed "Hpre".
  iNamed "HisSrv".
  wp_call.
  wp_loadField.
  wp_apply (acquire_spec with "HmuInv").
  iIntros "[Hlocked Hown]".
  iNamed "Hown".
  wp_pures.
  wp_loadField.
  wp_loadField.
  wp_pures.
  iNamed "HΨ".
  wp_if_destruct.
  { (* case: args.epoch ≤ s.epoch, do nothing *)
    wp_loadField.
    wp_apply (release_spec with "[-HΦ HΨ Hreply]").
    {
      iFrame "HmuInv Hlocked".
      iNext.
      iExists _, _, _, _, _, _.
      iFrame "∗#%".
    }
    wp_pures.
    iNamed "Hreply".
    wp_storeField.
    iRight in "HΨ".
    iApply ("HΦ" with "[HΨ]").
    2:{
      iExists _.
      instantiate (1:=enterNewEpochReply.mkC _ _ _ _).
      simpl.
      iFrame.
      done.
    }
    { iApply "HΨ". done. }
  }
  { (* case: args.epoch > s.epoch, can enter new epoch and return a vote *)
    assert (int.nat args.(enterNewEpochArgs.epoch) > int.nat st.(mp_epoch)) as Hineq by word.
    wp_storeField.
    wp_loadField.
    wp_storeField.
    wp_loadField.
    iNamed "Hreply".
    wp_storeField.
    wp_loadField.
    wp_storeField.
    wp_loadField.
    wp_storeField.
    wp_loadField.
    iDestruct (ghost_replica_helper1 with "Hghost") as "%HepochIneq".
    iMod (ghost_replica_enter_new_epoch with "Hghost") as "(Hghost & Htok & #Hrest)".
    { exact Hineq. }
    simpl in HepochIneq.

    wp_apply (release_spec with "[-HΦ HΨ Hreply_err Hreply_acceptedEpoch Hreply_nextIndex Hreply_ret Hreply_ret_sl Htok]").
    {
      iFrame "HmuInv Hlocked".
      iNext.
      iExists _, _, _, _, _, _.
      iFrame "∗#%".
      done.
    }
    wp_pures.
    iModIntro.
    iLeft in "HΨ".
    iSpecialize ("HΨ" with "[$Htok]").
    {
      instantiate (1:=enterNewEpochReply.mkC _ _ _ _).
      iExists st.(mp_log).
      iDestruct "Hrest" as "(Hacc & Hprop_lb & Hprop_facts)".
      simpl.
      iFrame "#".
      iPureIntro.
      split.
      {
        word.
      }
      split.
      {
        done.
      }
      done.
    }
    iApply ("HΦ" with "HΨ").
    iExists _.
    simpl.
    iFrame "∗#".
  }
Qed.

End enternewepoch_proof.
