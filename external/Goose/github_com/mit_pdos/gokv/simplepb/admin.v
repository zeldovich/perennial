(* autogenerated from github.com/mit-pdos/gokv/simplepb/admin *)
From Perennial.goose_lang Require Import prelude.
From Goose Require github_com.mit_pdos.gokv.simplepb.config.
From Goose Require github_com.mit_pdos.gokv.simplepb.e.
From Goose Require github_com.mit_pdos.gokv.simplepb.pb.

From Perennial.goose_lang Require Import ffi.grove_prelude.

(* admin.go *)

Definition EnterNewConfig: val :=
  rec: "EnterNewConfig" "configHost" "servers" :=
    (if: (slice.len "servers") = #0
    then
      (* log.Println("Tried creating empty config") *)
      e.EmptyConfig
    else
      let: "configCk" := config.MakeClerk "configHost" in
      let: ("epoch", "oldServers") := config.Clerk__ReserveEpochAndGetConfig "configCk" in
      (* log.Printf("Reserved %d", epoch) *)
      let: "id" := ((rand.RandomUint64 #()) + #1) `rem` (slice.len "oldServers") in
      let: "oldClerk" := pb.MakeClerk (SliceGet uint64T "oldServers" "id") in
      let: "reply" := pb.Clerk__GetState "oldClerk" (struct.new pb.GetStateArgs [
        "Epoch" ::= "epoch"
      ]) in
      (if: (struct.loadF pb.GetStateReply "Err" "reply") ≠ e.None
      then
        (* log.Printf("Error while getting state and sealing in epoch %d", epoch) *)
        struct.loadF pb.GetStateReply "Err" "reply"
      else
        let: "clerks" := NewSlice ptrT (slice.len "servers") in
        let: "i" := ref_to uint64T #0 in
        Skip;;
        (for: (λ: <>, (![uint64T] "i") < (slice.len "clerks")); (λ: <>, Skip) := λ: <>,
          SliceSet ptrT "clerks" (![uint64T] "i") (pb.MakeClerk (SliceGet uint64T "servers" (![uint64T] "i")));;
          "i" <-[uint64T] ((![uint64T] "i") + #1);;
          Continue);;
        let: "wg" := waitgroup.New #() in
        let: "errs" := NewSlice uint64T (slice.len "clerks") in
        "i" <-[uint64T] #0;;
        Skip;;
        (for: (λ: <>, (![uint64T] "i") < (slice.len "clerks")); (λ: <>, Skip) := λ: <>,
          waitgroup.Add "wg" #1;;
          let: "clerk" := SliceGet ptrT "clerks" (![uint64T] "i") in
          let: "locali" := ![uint64T] "i" in
          Fork (SliceSet uint64T "errs" "locali" (pb.Clerk__SetState "clerk" (struct.new pb.SetStateArgs [
                  "Epoch" ::= "epoch";
                  "State" ::= struct.loadF pb.GetStateReply "State" "reply";
                  "NextIndex" ::= struct.loadF pb.GetStateReply "NextIndex" "reply";
                  "CommittedNextIndex" ::= struct.loadF pb.GetStateReply "CommittedNextIndex" "reply"
                ]));;
                waitgroup.Done "wg");;
          "i" <-[uint64T] ((![uint64T] "i") + #1);;
          Continue);;
        waitgroup.Wait "wg";;
        let: "err" := ref_to uint64T e.None in
        "i" <-[uint64T] #0;;
        Skip;;
        (for: (λ: <>, (![uint64T] "i") < (slice.len "errs")); (λ: <>, Skip) := λ: <>,
          let: "err2" := SliceGet uint64T "errs" (![uint64T] "i") in
          (if: "err2" ≠ e.None
          then "err" <-[uint64T] "err2"
          else #());;
          "i" <-[uint64T] ((![uint64T] "i") + #1);;
          Continue);;
        (if: (![uint64T] "err") ≠ e.None
        then
          (* log.Println("Error while setting state and entering new epoch") *)
          ![uint64T] "err"
        else
          (if: (config.Clerk__TryWriteConfig "configCk" "epoch" "servers") ≠ e.None
          then
            (* log.Println("Error while writing to config service") *)
            e.Stale
          else
            pb.Clerk__BecomePrimary (SliceGet ptrT "clerks" #0) (struct.new pb.BecomePrimaryArgs [
              "Epoch" ::= "epoch";
              "Replicas" ::= "servers"
            ]);;
            e.None)))).

(* init.go *)

Definition InitializeSystem: val :=
  rec: "InitializeSystem" "configHost" "servers" :=
    let: "configCk" := config.MakeClerk "configHost" in
    config.Clerk__TryWriteConfig "configCk" #0 "servers";;
    EnterNewConfig "configHost" "servers".
