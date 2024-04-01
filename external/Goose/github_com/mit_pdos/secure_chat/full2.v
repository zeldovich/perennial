(* autogenerated from github.com/mit-pdos/secure-chat/full2 *)
From Perennial.goose_lang Require Import prelude.
From Goose Require github_com.mit_pdos.gokv.urpc.
From Goose Require github_com.mit_pdos.secure_chat.full2.fc_ffi_shim.
From Goose Require github_com.mit_pdos.secure_chat.full2.shared.

From Perennial.goose_lang Require Import ffi.grove_prelude.

(* app.go *)

Definition Alice := struct.decl [
  "ck" :: ptrT;
  "a_msg" :: ptrT;
  "b_msg" :: ptrT
].

(* Clerk from clerk.go *)

(* Clerk only supports sequential calls to its methods. *)
Definition Clerk := struct.decl [
  "cli" :: ptrT;
  "log" :: slice.T ptrT;
  "myNum" :: uint64T;
  "signer" :: ptrT;
  "verifiers" :: slice.T ptrT
].

Definition Clerk__Put: val :=
  rec: "Clerk__Put" "c" "m" :=
    let: "m2" := shared.MsgT__Copy "m" in
    let: "log" := NewSlice ptrT (slice.len (struct.loadF Clerk "log" "c")) in
    SliceCopy ptrT "log" (struct.loadF Clerk "log" "c");;
    let: "log2" := SliceAppend ptrT "log" "m2" in
    let: "log2B" := shared.EncodeMsgTSlice "log2" in
    let: ("sig", "err1") := fc_ffi_shim.SignerT__Sign (struct.loadF Clerk "signer" "c") "log2B" in
    control.impl.Assume ("err1" = shared.ErrNone);;
    let: "pa" := shared.NewPutArg (struct.loadF Clerk "myNum" "c") "sig" "log2B" in
    let: "argB" := shared.PutArg__Encode "pa" in
    let: "r" := NewSlice byteT #0 in
    let: "err2" := urpc.Client__Call (struct.loadF Clerk "cli" "c") shared.RpcPut "argB" "r" #100 in
    control.impl.Assume ("err2" = urpc.ErrNone);;
    #().

Definition Alice__One: val :=
  rec: "Alice__One" "a" :=
    Clerk__Put (struct.loadF Alice "ck" "a") (struct.loadF Alice "a_msg" "a");;
    #().

Definition Clerk__Get: val :=
  rec: "Clerk__Get" "c" :=
    let: "nilRet" := NewSlice ptrT #0 in
    let: "r" := NewSlice byteT #0 in
    let: "err1" := urpc.Client__Call (struct.loadF Clerk "cli" "c") shared.RpcGet (NewSlice byteT #0) "r" #100 in
    (if: "err1" ≠ urpc.ErrNone
    then ("nilRet", shared.ErrSome)
    else
      let: ("arg", "err2") := shared.DecodePutArg "r" in
      (if: "err2" ≠ shared.ErrNone
      then ("nilRet", shared.ErrSome)
      else
        let: "pk" := SliceGet ptrT (struct.loadF Clerk "verifiers" "c") (struct.loadF shared.PutArg "Sender" "arg") in
        let: "err3" := fc_ffi_shim.VerifierT__Verify "pk" (struct.loadF shared.PutArg "Sig" "arg") (struct.loadF shared.PutArg "LogB" "arg") in
        (if: "err3" ≠ shared.ErrNone
        then ("nilRet", shared.ErrSome)
        else
          let: ("log", <>) := shared.DecodeMsgTSlice (struct.loadF shared.PutArg "LogB" "arg") in
          (if: (~ (shared.IsMsgTSlicePrefix (struct.loadF Clerk "log" "c") "log"))
          then ("nilRet", shared.ErrSome)
          else
            struct.storeF Clerk "log" "c" (shared.CopyMsgTSlice "log");;
            ("log", shared.ErrNone))))).

Definition Alice__Two: val :=
  rec: "Alice__Two" "a" :=
    let: ("g", "err") := Clerk__Get (struct.loadF Alice "ck" "a") in
    control.impl.Assume ("err" = shared.ErrNone);;
    (if: #2 ≤ (slice.len "g")
    then
      control.impl.Assert ((struct.loadF shared.MsgT "Body" (SliceGet ptrT "g" #0)) = (struct.loadF shared.MsgT "Body" (struct.loadF Alice "a_msg" "a")));;
      control.impl.Assert ((struct.loadF shared.MsgT "Body" (SliceGet ptrT "g" #1)) = (struct.loadF shared.MsgT "Body" (struct.loadF Alice "b_msg" "a")));;
      control.impl.Assert ((slice.len "g") = #2);;
      let: ("g2", "err") := Clerk__Get (struct.loadF Alice "ck" "a") in
      control.impl.Assume ("err" = shared.ErrNone);;
      control.impl.Assert ((struct.loadF shared.MsgT "Body" (SliceGet ptrT "g2" #0)) = (struct.loadF shared.MsgT "Body" (struct.loadF Alice "a_msg" "a")));;
      control.impl.Assert ((struct.loadF shared.MsgT "Body" (SliceGet ptrT "g2" #1)) = (struct.loadF shared.MsgT "Body" (struct.loadF Alice "b_msg" "a")));;
      control.impl.Assert ((slice.len "g2") = #2);;
      SliceGet ptrT "g" #0
    else slice.nil).

Definition MakeClerk: val :=
  rec: "MakeClerk" "host" "myNum" "signer" "verifiers" :=
    let: "c" := struct.new Clerk [
    ] in
    struct.storeF Clerk "cli" "c" (urpc.MakeClient "host");;
    struct.storeF Clerk "log" "c" (NewSlice ptrT #0);;
    struct.storeF Clerk "myNum" "c" "myNum";;
    struct.storeF Clerk "signer" "c" "signer";;
    struct.storeF Clerk "verifiers" "c" "verifiers";;
    "c".

Definition MakeAlice: val :=
  rec: "MakeAlice" "host" "signer" "verifiers" :=
    let: "a" := struct.new Alice [
    ] in
    struct.storeF Alice "ck" "a" (MakeClerk "host" shared.AliceNum "signer" "verifiers");;
    struct.storeF Alice "a_msg" "a" (struct.new shared.MsgT [
      "Body" ::= shared.AliceMsg
    ]);;
    struct.storeF Alice "b_msg" "a" (struct.new shared.MsgT [
      "Body" ::= shared.BobMsg
    ]);;
    "a".

Definition Bob := struct.decl [
  "ck" :: ptrT;
  "a_msg" :: ptrT;
  "b_msg" :: ptrT
].

Definition Bob__One: val :=
  rec: "Bob__One" "b" :=
    let: ("g", "err") := Clerk__Get (struct.loadF Bob "ck" "b") in
    control.impl.Assume ("err" = shared.ErrNone);;
    (if: #1 ≤ (slice.len "g")
    then
      control.impl.Assert ((struct.loadF shared.MsgT "Body" (SliceGet ptrT "g" #0)) = (struct.loadF shared.MsgT "Body" (struct.loadF Bob "a_msg" "b")));;
      control.impl.Assert ((slice.len "g") = #1);;
      Clerk__Put (struct.loadF Bob "ck" "b") (struct.loadF Bob "b_msg" "b");;
      SliceGet ptrT "g" #0
    else slice.nil).

Definition MakeBob: val :=
  rec: "MakeBob" "host" "signer" "verifiers" :=
    let: "b" := struct.new Bob [
    ] in
    struct.storeF Bob "ck" "b" (MakeClerk "host" shared.BobNum "signer" "verifiers");;
    struct.storeF Bob "a_msg" "b" (struct.new shared.MsgT [
      "Body" ::= shared.AliceMsg
    ]);;
    struct.storeF Bob "b_msg" "b" (struct.new shared.MsgT [
      "Body" ::= shared.BobMsg
    ]);;
    "b".

(* clerk.go *)
