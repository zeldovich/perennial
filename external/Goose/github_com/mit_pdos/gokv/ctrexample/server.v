(* autogenerated from github.com/mit-pdos/gokv/ctrexample/server *)
From Perennial.goose_lang Require Import prelude.
From Goose Require github_com.mit_pdos.gokv.urpc.
From Goose Require github_com.tchajed.marshal.

From Perennial.goose_lang Require Import ffi.grove_prelude.

Definition CtrServer := struct.decl [
  "mu" :: ptrT;
  "val" :: uint64T;
  "filename" :: stringT
].

(* requires lock to be held *)
Definition CtrServer__MakeDurable: val :=
  rec: "CtrServer__MakeDurable" "s" :=
    let: "e" := marshal.NewEnc #8 in
    marshal.Enc__PutInt "e" (struct.loadF CtrServer "val" "s");;
    grove_ffi.FileWrite (struct.loadF CtrServer "filename" "s") (marshal.Enc__Finish "e");;
    #().

Definition CtrServer__FetchAndIncrement: val :=
  rec: "CtrServer__FetchAndIncrement" "s" :=
    lock.acquire (struct.loadF CtrServer "mu" "s");;
    let: "ret" := struct.loadF CtrServer "val" "s" in
    struct.storeF CtrServer "val" "s" ((struct.loadF CtrServer "val" "s") + #1);;
    CtrServer__MakeDurable "s";;
    lock.release (struct.loadF CtrServer "mu" "s");;
    "ret".

(* the boot/main() function for the server *)
Definition main: val :=
  rec: "main" <> :=
    let: "me" := #53021371269120 in
    let: "s" := struct.alloc CtrServer (zero_val (struct.t CtrServer)) in
    struct.storeF CtrServer "mu" "s" (lock.new #());;
    struct.storeF CtrServer "filename" "s" #(str"ctr");;
    let: "a" := grove_ffi.FileRead (struct.loadF CtrServer "filename" "s") in
    (if: (slice.len "a") = #0
    then struct.storeF CtrServer "val" "s" #0
    else
      let: "d" := marshal.NewDec "a" in
      struct.storeF CtrServer "val" "s" (marshal.Dec__GetInt "d"));;
    let: "handlers" := NewMap uint64T ((slice.T byteT) -> ptrT -> unitT)%ht #() in
    MapInsert "handlers" #0 (λ: "args" "reply",
      let: "v" := CtrServer__FetchAndIncrement "s" in
      let: "e" := marshal.NewEnc #8 in
      marshal.Enc__PutInt "e" "v";;
      "reply" <-[slice.T byteT] (marshal.Enc__Finish "e");;
      #()
      );;
    let: "rs" := urpc.MakeServer "handlers" in
    urpc.Server__Serve "rs" "me";;
    #().
