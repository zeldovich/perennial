From Perennial.program_proof Require Import grove_prelude.
From Goose.github_com.mit_pdos.gokv.simplepb.apps Require Import closed.

From Perennial.goose_lang Require adequacy dist_adequacy.
From Perennial.goose_lang.ffi Require grove_ffi_adequacy.
From Perennial.program_logic Require dist_lang.

From Perennial.program_proof.simplepb Require Import config_proof pb_definitions
     pb_protocol pb_init_proof config_protocol_proof.
From Perennial.program_proof.simplepb Require Import kvee_proof admin_proof.
From Perennial.program_proof.simplepb.simplelog Require Import proof.
From Perennial.program_proof.grove_shared Require Import urpc_proof.
From Perennial.program_proof.simplepb.apps Require Import closed_wpcs.
From Perennial.goose_lang Require Import crash_borrow crash_modality.
From Perennial.goose_lang Require Import typed_slice.

Module closed.

Import adequacy dist_adequacy grove_ffi_adequacy dist_lang.

Definition grove_dist_adequate
           (enonidempσs: list (node_init_cfg (Λ:=goose_lang)))
           (ebσs: list (goose_lang.expr * goose_lang.state))
           (g: goose_lang.global_state) :=
  let ρs := fmap (λ ebσ, {| init_thread := fst ebσ;
                           init_restart := fst ebσ;
                           init_local_state := snd ebσ |})
               ebσs in
  dist_adequacy.dist_adequate (CS := goose_crash_lang) (enonidempσs ++ ρs) g.

Definition kv_pbΣ := #[heapΣ; ekvΣ].

Definition configHost : chan := U64 10.
Definition r1Host: chan := U64 1.
Definition r2Host: chan := U64 2.


#[global]
Instance sys_inv_into_crash `{!heapGS Σ} EntryType `{!pbG Σ} γsys :
  IntoCrash (is_pb_system_invs γsys) (λ hG', @is_pb_system_invs EntryType Σ (_ hG') _ γsys)
.
Proof.
  rewrite /IntoCrash /is_pb_system_invs.
  iIntros "$". iIntros; eauto.
Qed.

(* The globalGS equality should actually always be the case (or more precisely,
 we should be unbundling, but let's include it here in the conclusion as a
 hack *)
#[global]
Instance is_pb_host_into_crash `{hG0: !heapGS Σ} PBRecord `{!pbG Σ} u γ1 γ2 :
  IntoCrash (is_pb_host u γ1 γ2)
    (λ hG, ⌜ hG0.(goose_globalGS) = hG.(goose_globalGS) ⌝ ∗ is_pb_host (pb_record:=PBRecord) u γ1 γ2)%I
.
Proof.
  rewrite /IntoCrash /is_pb_host.
  iIntros "$". iIntros; eauto.
Qed.

#[global]
Instance is_pb_config_host_into_crash `{hG0: !heapGS Σ} PBRecord `{!pbG Σ} u γ:
  IntoCrash (is_pb_config_host u γ)
    (λ hG, ⌜ hG0.(goose_globalGS) = hG.(goose_globalGS) ⌝ ∗ is_pb_config_host (pb_record:=PBRecord) u γ)%I
.
Proof.
  rewrite /IntoCrash /is_pb_host.
  iIntros "$". iIntros; eauto.
Qed.

#[global]
Instance file_crash_into_crash `{hG0: !heapGS Σ} SMRecord `{!pbG Σ} γsys γsrv1 data:
  IntoCrash (file_crash (own_Server_ghost_f γsys γsrv1) data)
    (λ hG, (file_crash (sm_record := SMRecord) (own_Server_ghost_f γsys γsrv1 ) data)).
Proof.
  rewrite /IntoCrash /file_crash.
  iIntros "$". iIntros; eauto.
Qed.

Definition kv_replica_main_crash_cond `{ekvG Σ} γsys fname γsrv1:=
(λ hG : heapGS Σ, ∃ data',
    (fname f↦ data') ∗ ▷ file_crash (own_Server_ghost_f γsys γsrv1) data')%I.

Lemma wpr_kv_replica_main fname me γsys γsrv {Σ} {HKV: ekvG Σ}
                               {HG} {HL}:
  let hG := {| goose_globalGS := HG; goose_localGS := HL |} in
  "Hinvs" ∷ is_pb_system_invs γsys -∗
  "Hsrvhost1" ∷ is_pb_host me γsys γsrv -∗
  "Hconfhost" ∷ is_pb_config_host configHost γsys -∗
  "Hinit" ∷ fname f↦[] -∗
  "Hfile_crash" ∷ file_crash (own_Server_ghost_f γsys γsrv) [] -∗
  wpr NotStuck ⊤ (kv_replica_main #(LitString fname) #me) (kv_replica_main #(LitString fname) #me) (λ _ : goose_lang.val, True)
    (λ _ , True) (λ _ _, True).
Proof.
   iIntros. iNamed.
   iApply (idempotence_wpr with "[Hinit Hfile_crash] []").
   {
     instantiate (1:=kv_replica_main_crash_cond γsys fname γsrv).
     simpl.
     wpc_apply (wpc_kv_replica_main γsys γsrv with "[] [$] [$] [$]").
     { iIntros "$". }
     iExists _. iFrame.
   }
   { (* recovery *)
     rewrite /hG.
     clear hG.
     iModIntro.
     iIntros (????) "Hcrash".
     iNext.
     iDestruct "Hcrash" as (?) "[Hfile Hcrash]".
     simpl.
     set (hG' := HeapGS _ _ hL').
     iDestruct "Hinvs" as "-#Hinvs".
     iDestruct "Hsrvhost1" as "-#Hsrvhost1".
     iDestruct "Hconfhost" as "-#Hconfhost".
     iCrash.
     iIntros "_".
     destruct hL as [HG'' ?].
     iSplit; first done.
     iDestruct "Hsrvhost1" as "(%&Hsrvhost1)".
     iDestruct "Hconfhost" as "(%&Hconfhost)".
     subst.
     clear hG'.
     clear hL'.
     (* overcome impedence mismatch between heapGS (bundled) and gooseGLobalGS+gooseLocalGS (split) proofs *)
     set (hG2' := HeapGS _ _ goose_localGS).
     simpl.
     wpc_apply (wpc_kv_replica_main (heapGS0:=hG2') γsys γsrv with "[] [$] [$] [$]").
     { iIntros "H".
       iDestruct "H" as (?) "[Hfile Hcrash]".
       iExists _.
       iFrame.
     }
     iExists _. iFrame.
   }
Qed.

Lemma wp_config_main γconf {Σ} {HKV: ekvG Σ} {HG} {HL}:
  let hG := {| goose_globalGS := HG; goose_localGS := HL |} in
  "HconfInit" ∷ makeConfigServer_pre γconf [U64 1; U64 2] ∗
  "#Hhost" ∷ is_config_host configHost γconf -∗
  WP config_main #() {{ _, True }}
.
Proof.
  intros ?.
  iNamed 1.
  wp_call.
  wp_apply (wp_NewSlice).
  iIntros (?) "Hsl".
  wp_apply wp_ref_to.
  { done. }
  iIntros (servers_ptr) "Hservers".
  wp_pures.

  wp_apply (wp_LoadAt with "[$Hservers]").
  iIntros "Hservers".
  wp_apply (wp_SliceAppend with "Hsl").
  iIntros (?) "Hsl".
  wp_apply (wp_StoreAt with "[$Hservers]").
  { done. }
  iIntros "Hservers".

  wp_apply (wp_LoadAt with "[$Hservers]").
  iIntros "Hservers".
  wp_apply (wp_SliceAppend with "Hsl").
  iIntros (?) "Hsl".
  wp_apply (wp_StoreAt with "[$Hservers]").
  { done. }
  iIntros "Hservers".

  wp_apply (wp_LoadAt with "[$Hservers]").
  iIntros "Hservers".
  iDestruct (own_slice_to_small with "Hsl") as "Hsl".
  rewrite replicate_0.
  simpl.
  wp_apply (config_proof.wp_MakeServer with "[$HconfInit $Hsl]").
  iIntros (?) "#Hissrv".
  wp_apply (wp_Server__Serve with "[$]").
  {
    iFrame "Hissrv".
  }
  wp_pures.
  done.
Qed.

(* There's one of these in kvee_proof.v, so I got rid of this.
   This is probably a remnant of an older version of the proof in which the subG
   wasn't proven anywhere else.
 *)

Local Instance subG_ekvΣ {Σ} : subG kv_pbΣ Σ → ekvG Σ.
Proof. intros. solve_inG. Qed.

Definition replica_fname := "kv.data".

(* FIXME: put this in the file that defines ekvΣ? *)
Opaque ekvΣ.
Lemma kv_pb_boot :
  ∀ σconfig σsrv1 σsrv2 (g : goose_lang.global_state),
  (* *)
  chan_msg_bounds g.(global_world).(grove_net) →

  file_content_bounds σconfig.(world).(grove_node_files) →
  file_content_bounds σsrv1.(world).(grove_node_files) →
  file_content_bounds σsrv2.(world).(grove_node_files) →

  σsrv1.(world).(grove_node_files) !! replica_fname = Some [] →
  σsrv2.(world).(grove_node_files) !! replica_fname = Some [] →

  g.(global_world).(grove_net) !! configHost = Some (∅ : gset message) →
  g.(global_world).(grove_net) !! r1Host = Some (∅ : gset message) →
  g.(global_world).(grove_net) !! r2Host = Some (∅ : gset message) →
  grove_dist_adequate
    [ {| init_thread := config_main #() ; init_restart := of_val #(); init_local_state := σconfig |}]
    [(kv_replica_main #(LitString replica_fname) #(r1Host:u64), σsrv1);
     (kv_replica_main #(LitString replica_fname) #(r2Host:u64), σsrv2)] g (λ _, True).
Proof.
  intros ????.
  intros Hinitg Hinitconfig Hinitr1 Hinitr2 Hinitr1file Hinitr2file HconfChan Hr1Chan Hr2Chan.
  eapply (grove_ffi_dist_adequacy (kv_pbΣ)).
  { assumption. }
  { repeat constructor; naive_solver. }

  intros Hheap.
  iIntros "Hchan".
  iSplitR ""; last first.
  { iModIntro. iMod (fupd_mask_subseteq ∅); eauto. }

  (* First, pre-set up the two KV replica servers *)
  iMod (prealloc_simplepb_server) as (γsrv1) "[#Hsrv1wit Hsrv1]".
  iMod (prealloc_simplepb_server) as (γsrv2) "[#Hsrv2wit Hsrv2]".

  set (confγs:=[γsrv1 ; γsrv2]).
  iMod (alloc_simplepb_system confγs with "[]") as (γpb) "H".
  { simpl. lia. }
  {
    iIntros.
    rewrite /confγs elem_of_list_In /= in H.
    naive_solver.
  }
  iDestruct "H" as "(#Hinvs & Hlog & #Hwits & Hconf1 & Hconf2 & #Hclient_invs)".

  (* Now, set up the exactly-once kv system *)
  iMod (alloc_ekv with "Hlog") as (?) "[#Hclient_invs2 Hkvs]".

  (* Now, set up all the hosts *)
  iDestruct (big_sepM_delete with "Hchan") as "[HconfChan Hchan]".
  { apply HconfChan. } (* get out conf chan points-to for later *)

  iDestruct (big_sepM_delete with "Hchan") as "[Hr1Chan Hchan]".
  { rewrite lookup_delete_Some. split; last apply Hr1Chan. done. }
  iMod (pb_host_init r1Host with "Hr1Chan") as "#Hsrvhost1".

  iDestruct (big_sepM_delete with "Hchan") as "[Hr2Chan Hchan]".
  { rewrite lookup_delete_Some.
    rewrite lookup_delete_Some.
    split; last (split ; last apply Hr2Chan); done. }
  iMod (pb_host_init r2Host with "Hr2Chan") as "#Hsrvhost2".

  set (conf:=[r1Host ; r2Host]).
  iMod (alloc_pb_config_ghost γpb conf confγs with "[] Hconf1 Hconf2") as (γconf) "[#Hconf HconfInit]".
  {
    iFrame "#".
    by iApply big_sepL2_nil.
  }

  iMod (config_server_init configHost γconf with "HconfChan") as "#Hconfhost".

  iAssert (is_pb_config_host configHost γpb) with "[]" as "#HbConfHost".
  { iExists _. iFrame "#". }

  iModIntro.
  simpl. iSplitL "HconfInit".
  {
    iIntros (HL) "Hfiles".
    iModIntro.
    iExists (λ _, True%I), (λ _, True%I), (λ _ _, True%I).
    set (hG' := HeapGS _ _ _). (* overcome impedence mismatch between heapGS (bundled) and gooseGLobalGS+gooseLocalGS (split) proofs *)
    iApply (idempotence_wpr with "[HconfInit] []").
    {
      instantiate (1:=λ _, True%I).
      simpl.
      iApply wp_wpc.
      iApply (wp_config_main _ with "[$]").
    }
    { (* crash; there should actually be no crashes of the config server *)
      iModIntro.
      iIntros.
      iModIntro.
      rewrite /post_crash.
      iIntros. iModIntro.
      iSplit; first done. iIntros. iSplit; first done.
      set (hG2' := HeapGS _ _ _). (* overcome impedence mismatch between heapGS (bundled) and gooseGLobalGS+gooseLocalGS (split) proofs *)
      wpc_pures.
      { done. }
      done.
    }
  }
  iSplitL "Hsrv1".
  {
    iIntros (HL) "Hfiles".
    iDestruct (big_sepM_lookup_acc with "Hfiles") as "[HH _]".
    { done. }
    iSpecialize ("Hsrv1" $! γpb with "[]").
    { iApply "Hwits". iPureIntro. rewrite /confγs elem_of_list_In /= //. naive_solver. }
    iModIntro.
    iExists (λ _, True%I), (λ _, True%I), (λ _ _, True%I).
    set (hG' := HeapGS _ _ _).
    iAssert (file_crash (own_Server_ghost_f γpb _) []) with "[Hsrv1]" as "HfileCrash".
    { iLeft. by iFrame. }
    iApply (@wpr_kv_replica_main _ _ _ γsrv1 with "[$] [$] [$] [$] [$]").
  }
  (* TODO: do like above for replica main1 as separate lemma *)
  iSplitL "Hsrv2".
  {
    iIntros (HL) "Hfiles".
    iDestruct (big_sepM_lookup_acc with "Hfiles") as "[HH _]".
    { done. }
    iSpecialize ("Hsrv2" $! γpb with "[]").
    { iApply "Hwits". iPureIntro. rewrite /confγs elem_of_list_In /= //. naive_solver. }
    iModIntro.
    iExists (λ _, True%I), (λ _, True%I), (λ _ _, True%I).
    set (hG' := HeapGS _ _ _).
    iAssert (file_crash (own_Server_ghost_f γpb _) []) with "[Hsrv2]" as "HfileCrash".
    { iLeft. by iFrame. }
    iApply (@wpr_kv_replica_main _ _ _ γsrv2 with "[$] [$] [$] [$] [$]").
  }
  done.
Qed.

End closed.
