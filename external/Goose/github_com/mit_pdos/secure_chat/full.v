(* autogenerated from github.com/mit-pdos/secure-chat/full *)
From Perennial.goose_lang Require Import prelude.

Section code.
Context `{ext_ty: ext_types}.
Local Coercion Var' s: expr := Var s.

(* app.go *)

Definition aliceMsg : expr := #10.

Definition bobMsg : expr := #11.

(* msgT from lib.go *)

Definition msgT := struct.decl [
  "body" :: uint64T
].

Definition ChatCli := struct.decl [
  "log" :: slice.T ptrT;
  "lock" :: ptrT
].

Definition ChatCli__Put: val :=
  rec: "ChatCli__Put" "c" "m" :=
    lock.acquire (struct.loadF ChatCli "lock" "c");;
    struct.storeF ChatCli "log" "c" (SliceAppend ptrT (struct.loadF ChatCli "log" "c") "m");;
    lock.release (struct.loadF ChatCli "lock" "c");;
    #().

Definition ChatCli__Get: val :=
  rec: "ChatCli__Get" "c" :=
    lock.acquire (struct.loadF ChatCli "lock" "c");;
    let: "ret" := NewSlice ptrT (slice.len (struct.loadF ChatCli "log" "c")) in
    SliceCopy ptrT "ret" (struct.loadF ChatCli "log" "c");;
    lock.release (struct.loadF ChatCli "lock" "c");;
    "ret".

Definition alice: val :=
  rec: "alice" "c" :=
    let: "a_msg" := struct.new msgT [
      "body" ::= aliceMsg
    ] in
    let: "b_msg" := struct.new msgT [
      "body" ::= bobMsg
    ] in
    ChatCli__Put "c" "a_msg";;
    let: "g" := ChatCli__Get "c" in
    (if: #2 ≤ (slice.len "g")
    then
      control.impl.Assert ((struct.loadF msgT "body" (SliceGet ptrT "g" #0)) = (struct.loadF msgT "body" "a_msg"));;
      control.impl.Assert ((struct.loadF msgT "body" (SliceGet ptrT "g" #1)) = (struct.loadF msgT "body" "b_msg"));;
      control.impl.Assert ((slice.len "g") = #2);;
      let: "g2" := ChatCli__Get "c" in
      control.impl.Assert ((struct.loadF msgT "body" (SliceGet ptrT "g2" #0)) = (struct.loadF msgT "body" "a_msg"));;
      control.impl.Assert ((struct.loadF msgT "body" (SliceGet ptrT "g2" #1)) = (struct.loadF msgT "body" "b_msg"));;
      control.impl.Assert ((slice.len "g2") = #2);;
      #()
    else #()).

Definition bob: val :=
  rec: "bob" "c" :=
    let: "a_msg" := struct.new msgT [
      "body" ::= aliceMsg
    ] in
    let: "b_msg" := struct.new msgT [
      "body" ::= bobMsg
    ] in
    let: "g" := ChatCli__Get "c" in
    (if: #1 ≤ (slice.len "g")
    then
      control.impl.Assert ((struct.loadF msgT "body" (SliceGet ptrT "g" #0)) = (struct.loadF msgT "body" "a_msg"));;
      control.impl.Assert ((slice.len "g") = #1);;
      ChatCli__Put "c" "b_msg";;
      #()
    else #()).

Definition Init: val :=
  rec: "Init" <> :=
    let: "c" := struct.new ChatCli [
    ] in
    struct.storeF ChatCli "log" "c" (NewSlice ptrT #0);;
    struct.storeF ChatCli "lock" "c" (lock.new #());;
    "c".

Definition main: val :=
  rec: "main" <> :=
    let: "c" := Init #() in
    Fork (alice "c");;
    bob "c";;
    #().

(* lib.go *)

Definition errorT: ty := boolT.

Definition ERRNONE : expr := #false.

Definition ERRSOME : expr := #true.

End code.
