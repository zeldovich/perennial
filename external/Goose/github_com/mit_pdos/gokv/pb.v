(* autogenerated from github.com/mit-pdos/gokv/pb *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.grove_prelude.

From Goose Require github_com.mit_pdos.gokv.urpc.
From Goose Require github_com.tchajed.marshal.

(* 0_common.go *)

Definition Configuration := struct.decl [
  "Replicas" :: slice.T uint64T
].

Definition EncodePBConfiguration: val :=
  rec: "EncodePBConfiguration" "p" :=
    let: "enc" := marshal.NewEnc (#8 + #8 + #8 * slice.len (struct.loadF Configuration "Replicas" "p")) in
    marshal.Enc__PutInt "enc" (slice.len (struct.loadF Configuration "Replicas" "p"));;
    marshal.Enc__PutInts "enc" (struct.loadF Configuration "Replicas" "p");;
    marshal.Enc__Finish "enc".

Definition DecodePBConfiguration: val :=
  rec: "DecodePBConfiguration" "raw_conf" :=
    let: "c" := struct.alloc Configuration (zero_val (struct.t Configuration)) in
    let: "dec" := marshal.NewDec "raw_conf" in
    struct.storeF Configuration "Replicas" "c" (marshal.Dec__GetInts "dec" (marshal.Dec__GetInt "dec"));;
    "c".

(* 1_conf.go *)

Definition VersionedValue := struct.decl [
  "ver" :: uint64T;
  "val" :: slice.T byteT
].

Definition ConfServer := struct.decl [
  "mu" :: ptrT;
  "kvs" :: mapT (struct.t VersionedValue)
].

Definition CONF_PUT : expr := #1.

Definition CONF_GET : expr := #1.

Definition PutArgs := struct.decl [
  "key" :: uint64T;
  "prevVer" :: uint64T;
  "newVal" :: slice.T byteT
].

(* MARSHAL *)
Definition EncodePutArgs: val :=
  rec: "EncodePutArgs" "args" :=
    let: "enc" := marshal.NewEnc (#8 + #8 + slice.len (struct.loadF PutArgs "newVal" "args")) in
    marshal.Enc__PutInt "enc" (struct.loadF PutArgs "key" "args");;
    marshal.Enc__PutInt "enc" (struct.loadF PutArgs "prevVer" "args");;
    marshal.Enc__PutBytes "enc" (struct.loadF PutArgs "newVal" "args");;
    marshal.Enc__Finish "enc".

(* MARSHAL *)
Definition DecodePutArgs: val :=
  rec: "DecodePutArgs" "data" :=
    let: "dec" := marshal.NewDec "data" in
    let: "args" := struct.alloc PutArgs (zero_val (struct.t PutArgs)) in
    struct.storeF PutArgs "key" "args" (marshal.Dec__GetInt "dec");;
    struct.storeF PutArgs "prevVer" "args" (marshal.Dec__GetInt "dec");;
    struct.storeF PutArgs "newVal" "args" (marshal.Dec__GetBytes "dec" (slice.len "data" - #16));;
    "args".

Definition EncodeVersionedValue: val :=
  rec: "EncodeVersionedValue" "v" :=
    let: "enc" := marshal.NewEnc (#8 + slice.len (struct.loadF VersionedValue "val" "v")) in
    marshal.Enc__PutInt "enc" (struct.loadF VersionedValue "ver" "v");;
    marshal.Enc__PutBytes "enc" (struct.loadF VersionedValue "val" "v");;
    marshal.Enc__Finish "enc".

Definition DecodeVersionedValue: val :=
  rec: "DecodeVersionedValue" "data" :=
    let: "dec" := marshal.NewDec "data" in
    let: "v" := struct.alloc VersionedValue (zero_val (struct.t VersionedValue)) in
    struct.storeF VersionedValue "ver" "v" (marshal.Dec__GetInt "dec");;
    struct.storeF VersionedValue "val" "v" (marshal.Dec__GetBytes "dec" (slice.len "data" - #8));;
    "v".

Definition ConfServer__PutRPC: val :=
  rec: "ConfServer__PutRPC" "s" "args" :=
    lock.acquire (struct.loadF ConfServer "mu" "s");;
    let: (<>, "ok") := MapGet (struct.loadF ConfServer "kvs" "s") (struct.loadF PutArgs "key" "args") in
    (if: "ok"
    then
      (if: (struct.get VersionedValue "ver" (Fst (MapGet (struct.loadF ConfServer "kvs" "s") (struct.loadF PutArgs "key" "args"))) = struct.loadF PutArgs "prevVer" "args")
      then
        MapInsert (struct.loadF ConfServer "kvs" "s") (struct.loadF PutArgs "key" "args") (struct.mk VersionedValue [
          "ver" ::= struct.loadF PutArgs "prevVer" "args" + #1;
          "val" ::= struct.loadF PutArgs "newVal" "args"
        ])
      else #())
    else
      MapInsert (struct.loadF ConfServer "kvs" "s") (struct.loadF PutArgs "key" "args") (struct.mk VersionedValue [
        "ver" ::= struct.loadF PutArgs "prevVer" "args" + #1;
        "val" ::= struct.loadF PutArgs "newVal" "args"
      ]));;
    lock.release (struct.loadF ConfServer "mu" "s");;
    #true.

Definition GetReply := struct.decl [
  "ver" :: uint64T;
  "val" :: slice.T byteT
].

Definition ConfServer__GetRPC: val :=
  rec: "ConfServer__GetRPC" "s" "key" "v" :=
    lock.acquire (struct.loadF ConfServer "mu" "s");;
    struct.store VersionedValue "v" (Fst (MapGet (struct.loadF ConfServer "kvs" "s") "key"));;
    lock.release (struct.loadF ConfServer "mu" "s");;
    #().

Definition StartConfServer: val :=
  rec: "StartConfServer" "me" :=
    let: "s" := struct.alloc ConfServer (zero_val (struct.t ConfServer)) in
    struct.storeF ConfServer "mu" "s" (lock.new #());;
    struct.storeF ConfServer "kvs" "s" (NewMap (struct.t VersionedValue) #());;
    let: "handlers" := NewMap ((slice.T byteT -> ptrT -> unitT)%ht) #() in
    MapInsert "handlers" CONF_PUT (λ: "args" "rep",
      (if: ConfServer__PutRPC "s" (DecodePutArgs "args")
      then
        "rep" <-[slice.T byteT] NewSlice byteT #1;;
        #()
      else
        "rep" <-[slice.T byteT] NewSlice byteT #0;;
        #())
      );;
    MapInsert "handlers" CONF_GET (λ: "args" "rep",
      let: "v" := struct.alloc VersionedValue (zero_val (struct.t VersionedValue)) in
      ConfServer__GetRPC "s" (UInt64Get "args") "v";;
      #()
      );;
    let: "r" := urpc.MakeServer "handlers" in
    urpc.Server__Serve "r" "me";;
    #().

Definition ConfClerk := struct.decl [
  "cl" :: ptrT
].

Definition ConfClerk__Put: val :=
  rec: "ConfClerk__Put" "c" "key" "prevVer" "newVal" :=
    let: "raw_reply" := ref (zero_val (slice.T byteT)) in
    let: "raw_args" := EncodePutArgs (struct.new PutArgs [
      "key" ::= "key";
      "prevVer" ::= "prevVer";
      "newVal" ::= "newVal"
    ]) in
    let: "err" := urpc.Client__Call (struct.loadF ConfClerk "cl" "c") CONF_PUT "raw_args" "raw_reply" #100 in
    (if: ("err" = #0)
    then slice.len (![slice.T byteT] "raw_reply") > #0
    else #false).

Definition ConfClerk__Get: val :=
  rec: "ConfClerk__Get" "c" "key" :=
    let: "raw_reply" := ref (zero_val (slice.T byteT)) in
    let: "raw_args" := NewSlice byteT #8 in
    UInt64Put "raw_args" "key";;
    let: "err" := urpc.Client__Call (struct.loadF ConfClerk "cl" "c") CONF_GET "raw_args" "raw_reply" #100 in
    (if: ("err" = #0)
    then DecodeVersionedValue (![slice.T byteT] "raw_reply")
    else
      control.impl.Assume #false;;
      slice.nil).

Definition MakeConfClerk: val :=
  rec: "MakeConfClerk" "confServer" :=
    struct.new ConfClerk [
      "cl" ::= urpc.MakeClient "confServer"
    ].

(* 2_replica_clerk.go *)

Definition REPLICA_APPEND : expr := #0.

Definition REPLICA_GETLOG : expr := #1.

Definition REPLICA_BECOMEPRIMARY : expr := #2.

Definition REPLICA_HEARTBEAT : expr := #3.

Definition AppendArgs := struct.decl [
  "cn" :: uint64T;
  "commitIdx" :: uint64T;
  "log" :: slice.T byteT
].

Definition EncodeAppendArgs: val :=
  rec: "EncodeAppendArgs" "args" :=
    let: "enc" := marshal.NewEnc (#16 + slice.len (struct.loadF AppendArgs "log" "args")) in
    marshal.Enc__PutInt "enc" (struct.loadF AppendArgs "cn" "args");;
    marshal.Enc__PutInt "enc" (struct.loadF AppendArgs "commitIdx" "args");;
    marshal.Enc__PutBytes "enc" (struct.loadF AppendArgs "log" "args");;
    marshal.Enc__Finish "enc".

Definition DecodeAppendArgs: val :=
  rec: "DecodeAppendArgs" "raw_args" :=
    let: "a" := struct.alloc AppendArgs (zero_val (struct.t AppendArgs)) in
    let: "dec" := marshal.NewDec "raw_args" in
    struct.storeF AppendArgs "cn" "a" (marshal.Dec__GetInt "dec");;
    struct.storeF AppendArgs "commitIdx" "a" (marshal.Dec__GetInt "dec");;
    struct.storeF AppendArgs "log" "a" (marshal.Dec__GetBytes "dec" (slice.len "raw_args" - #16));;
    "a".

Definition BecomePrimaryArgs := struct.decl [
  "Cn" :: uint64T;
  "Conf" :: ptrT
].

Definition EncodeBecomePrimaryArgs: val :=
  rec: "EncodeBecomePrimaryArgs" "args" :=
    let: "encodedConf" := EncodePBConfiguration (struct.loadF BecomePrimaryArgs "Conf" "args") in
    let: "enc" := marshal.NewEnc (#8 + slice.len "encodedConf") in
    marshal.Enc__PutInt "enc" (struct.loadF BecomePrimaryArgs "Cn" "args");;
    marshal.Enc__PutBytes "enc" "encodedConf";;
    marshal.Enc__Finish "enc".

Definition DecodeBecomePrimaryArgs: val :=
  rec: "DecodeBecomePrimaryArgs" "raw_args" :=
    let: "a" := struct.alloc BecomePrimaryArgs (zero_val (struct.t BecomePrimaryArgs)) in
    let: "dec" := marshal.NewDec "raw_args" in
    struct.storeF BecomePrimaryArgs "Cn" "a" (marshal.Dec__GetInt "dec");;
    struct.storeF BecomePrimaryArgs "Conf" "a" (DecodePBConfiguration (SliceSkip byteT "raw_args" #8));;
    "a".

Definition ReplicaClerk := struct.decl [
  "cl" :: ptrT
].

Definition ReplicaClerk__AppendRPC: val :=
  rec: "ReplicaClerk__AppendRPC" "ck" "args" :=
    let: "raw_args" := EncodeAppendArgs "args" in
    let: "reply" := ref (zero_val (slice.T byteT)) in
    let: "err" := urpc.Client__Call (struct.loadF ReplicaClerk "cl" "ck") REPLICA_APPEND "raw_args" "reply" #100 in
    (if: ("err" = #0) && (slice.len (![slice.T byteT] "reply") > #0)
    then #true
    else #false).

Definition ReplicaClerk__BecomePrimaryRPC: val :=
  rec: "ReplicaClerk__BecomePrimaryRPC" "ck" "args" :=
    let: "raw_args" := EncodeBecomePrimaryArgs "args" in
    let: "reply" := ref (zero_val (slice.T byteT)) in
    let: "err" := urpc.Client__Call (struct.loadF ReplicaClerk "cl" "ck") REPLICA_BECOMEPRIMARY "raw_args" "reply" #20000 in
    control.impl.Assume ("err" = #0);;
    #().

Definition ReplicaClerk__HeartbeatRPC: val :=
  rec: "ReplicaClerk__HeartbeatRPC" "ck" :=
    let: "reply" := ref (zero_val (slice.T byteT)) in
    (urpc.Client__Call (struct.loadF ReplicaClerk "cl" "ck") REPLICA_HEARTBEAT (NewSlice byteT #0) "reply" #1000 = #0).

Definition MakeReplicaClerk: val :=
  rec: "MakeReplicaClerk" "host" :=
    let: "ck" := struct.alloc ReplicaClerk (zero_val (struct.t ReplicaClerk)) in
    struct.storeF ReplicaClerk "cl" "ck" (urpc.MakeClient "host");;
    "ck".

(* 3_replica.go *)

Definition LogEntry: ty := byteT.

Definition ReplicaServer := struct.decl [
  "mu" :: ptrT;
  "cn" :: uint64T;
  "conf" :: ptrT;
  "isPrimary" :: boolT;
  "replicaClerks" :: slice.T ptrT;
  "opLog" :: slice.T LogEntry;
  "commitIdx" :: uint64T;
  "commitCond" :: ptrT;
  "matchIdx" :: slice.T uint64T
].

Definition min: val :=
  rec: "min" "l" :=
    let: "m" := ref_to uint64T #18446744073709551615 in
    ForSlice uint64T <> "v" "l"
      (if: "v" < ![uint64T] "m"
      then "m" <-[uint64T] "v"
      else #());;
    ![uint64T] "m".

Definition ReplicaServer__postAppendRPC: val :=
  rec: "ReplicaServer__postAppendRPC" "s" "i" "args" :=
    lock.acquire (struct.loadF ReplicaServer "mu" "s");;
    (if: (struct.loadF ReplicaServer "cn" "s" = struct.loadF AppendArgs "cn" "args")
    then
      (if: SliceGet uint64T (struct.loadF ReplicaServer "matchIdx" "s") "i" < slice.len (struct.loadF AppendArgs "log" "args")
      then
        SliceSet uint64T (struct.loadF ReplicaServer "matchIdx" "s") "i" (slice.len (struct.loadF AppendArgs "log" "args"));;
        let: "m" := min (struct.loadF ReplicaServer "matchIdx" "s") in
        (if: "m" > struct.loadF ReplicaServer "commitIdx" "s"
        then struct.storeF ReplicaServer "commitIdx" "s" "m"
        else #())
      else #())
    else #());;
    lock.release (struct.loadF ReplicaServer "mu" "s");;
    #().

(* This should be invoked locally by services to attempt appending op to the
   log *)
Definition ReplicaServer__StartAppend: val :=
  rec: "ReplicaServer__StartAppend" "s" "op" :=
    lock.acquire (struct.loadF ReplicaServer "mu" "s");;
    (if: ~ (struct.loadF ReplicaServer "isPrimary" "s")
    then
      lock.release (struct.loadF ReplicaServer "mu" "s");;
      #false
    else
      struct.storeF ReplicaServer "opLog" "s" (SliceAppend byteT (struct.loadF ReplicaServer "opLog" "s") "op");;
      SliceSet uint64T (struct.loadF ReplicaServer "matchIdx" "s") #0 (slice.len (struct.loadF ReplicaServer "opLog" "s"));;
      let: "clerks" := struct.loadF ReplicaServer "replicaClerks" "s" in
      let: "args" := struct.new AppendArgs [
        "cn" ::= struct.loadF ReplicaServer "cn" "s";
        "log" ::= struct.loadF ReplicaServer "opLog" "s";
        "commitIdx" ::= struct.loadF ReplicaServer "commitIdx" "s"
      ] in
      lock.release (struct.loadF ReplicaServer "mu" "s");;
      ForSlice ptrT "i" "ck" "clerks"
        (let: "ck" := "ck" in
        let: "i" := "i" in
        Fork (ReplicaClerk__AppendRPC "ck" "args";;
              ReplicaServer__postAppendRPC "s" ("i" + #1) "args"));;
      #true).

Definition ReplicaServer__GetCommittedLog: val :=
  rec: "ReplicaServer__GetCommittedLog" "s" :=
    lock.acquire (struct.loadF ReplicaServer "mu" "s");;
    let: "r" := SliceTake (struct.loadF ReplicaServer "opLog" "s") (struct.loadF ReplicaServer "commitIdx" "s") in
    lock.release (struct.loadF ReplicaServer "mu" "s");;
    "r".

Definition ReplicaServer__AppendRPC: val :=
  rec: "ReplicaServer__AppendRPC" "s" "args" :=
    lock.acquire (struct.loadF ReplicaServer "mu" "s");;
    (if: struct.loadF ReplicaServer "cn" "s" > struct.loadF AppendArgs "cn" "args"
    then
      lock.release (struct.loadF ReplicaServer "mu" "s");;
      #false
    else
      (if: (struct.loadF ReplicaServer "cn" "s" < struct.loadF AppendArgs "cn" "args") || (slice.len (struct.loadF AppendArgs "log" "args") > slice.len (struct.loadF ReplicaServer "opLog" "s"))
      then
        struct.storeF ReplicaServer "opLog" "s" (struct.loadF AppendArgs "log" "args");;
        struct.storeF ReplicaServer "cn" "s" (struct.loadF AppendArgs "cn" "args")
      else #());;
      (if: struct.loadF AppendArgs "commitIdx" "args" > struct.loadF ReplicaServer "commitIdx" "s"
      then struct.storeF ReplicaServer "commitIdx" "s" (struct.loadF AppendArgs "commitIdx" "args")
      else #());;
      struct.storeF ReplicaServer "isPrimary" "s" #false;;
      lock.release (struct.loadF ReplicaServer "mu" "s");;
      #true).

(* controller tells the primary to become the primary, and gives it the config *)
Definition ReplicaServer__BecomePrimaryRPC: val :=
  rec: "ReplicaServer__BecomePrimaryRPC" "s" "args" :=
    lock.acquire (struct.loadF ReplicaServer "mu" "s");;
    (* log.Printf("Becoming primary in %d, %+v", args.Cn, args.Conf.Replicas) *)
    (if: struct.loadF ReplicaServer "cn" "s" ≥ struct.loadF BecomePrimaryArgs "Cn" "args"
    then
      lock.release (struct.loadF ReplicaServer "mu" "s");;
      #()
    else
      (if: (struct.loadF BecomePrimaryArgs "Cn" "args" > struct.loadF ReplicaServer "cn" "s" + #1) && (struct.loadF ReplicaServer "cn" "s" = #0)
      then
        control.impl.Assume #false;;
        #()
      else
        struct.storeF ReplicaServer "isPrimary" "s" #true;;
        struct.storeF ReplicaServer "cn" "s" (struct.loadF BecomePrimaryArgs "Cn" "args");;
        struct.storeF ReplicaServer "matchIdx" "s" (NewSlice uint64T (slice.len (struct.loadF Configuration "Replicas" (struct.loadF BecomePrimaryArgs "Conf" "args"))));;
        struct.storeF ReplicaServer "replicaClerks" "s" (NewSlice ptrT (slice.len (struct.loadF Configuration "Replicas" (struct.loadF BecomePrimaryArgs "Conf" "args")) - #1));;
        ForSlice ptrT "i" <> (struct.loadF ReplicaServer "replicaClerks" "s")
          (SliceSet ptrT (struct.loadF ReplicaServer "replicaClerks" "s") "i" (MakeReplicaClerk (SliceGet uint64T (struct.loadF Configuration "Replicas" (struct.loadF BecomePrimaryArgs "Conf" "args")) ("i" + #1))));;
        lock.release (struct.loadF ReplicaServer "mu" "s");;
        #())).

(* used for recovery/adding a new node into the system *)
Definition ReplicaServer__GetCommitLogRPC: val :=
  rec: "ReplicaServer__GetCommitLogRPC" "s" <> "reply" :=
    lock.acquire (struct.loadF ReplicaServer "mu" "s");;
    "reply" <-[slice.T byteT] SliceTake (struct.loadF ReplicaServer "opLog" "s") (struct.loadF ReplicaServer "commitIdx" "s");;
    lock.release (struct.loadF ReplicaServer "mu" "s");;
    #().

Definition StartReplicaServer: val :=
  rec: "StartReplicaServer" "me" :=
    let: "s" := struct.alloc ReplicaServer (zero_val (struct.t ReplicaServer)) in
    struct.storeF ReplicaServer "mu" "s" (lock.new #());;
    struct.storeF ReplicaServer "opLog" "s" (NewSlice LogEntry #0);;
    struct.storeF ReplicaServer "commitIdx" "s" #0;;
    struct.storeF ReplicaServer "cn" "s" #0;;
    struct.storeF ReplicaServer "isPrimary" "s" #false;;
    let: "handlers" := NewMap ((slice.T byteT -> ptrT -> unitT)%ht) #() in
    MapInsert "handlers" REPLICA_APPEND (λ: "raw_args" "raw_reply",
      let: "a" := DecodeAppendArgs "raw_args" in
      (if: ReplicaServer__AppendRPC "s" "a"
      then
        "raw_reply" <-[slice.T byteT] NewSlice byteT #1;;
        #()
      else
        "raw_reply" <-[slice.T byteT] NewSlice byteT #0;;
        #())
      );;
    MapInsert "handlers" REPLICA_GETLOG (ReplicaServer__GetCommitLogRPC "s");;
    MapInsert "handlers" REPLICA_BECOMEPRIMARY (λ: "raw_args" "raw_reply",
      ReplicaServer__BecomePrimaryRPC "s" (DecodeBecomePrimaryArgs "raw_args");;
      #()
      );;
    MapInsert "handlers" REPLICA_HEARTBEAT (λ: <> <>,
      #()
      );;
    let: "r" := urpc.MakeServer "handlers" in
    urpc.Server__Serve "r" "me";;
    "s".
