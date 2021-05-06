(* autogenerated from github.com/mit-pdos/gokv/memkv *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.dist_prelude.

From Goose Require github_com.mit_pdos.gokv.urpc.rpc.
From Goose Require github_com.tchajed.marshal.

(* 0_common.go *)

Definition HostName: ty := uint64T.

Definition ValueType: ty := uint64T.

Definition ErrorType: ty := uint64T.

Definition ENone : expr := #0.

Definition EDontHaveShard : expr := #1.

Definition NSHARD : expr := #65536.

Definition KV_FRESHCID : expr := #0.

Definition KV_PUT : expr := #1.

Definition KV_GET : expr := #2.

Definition KV_CONDITIONAL_PUT : expr := #3.

Definition KV_INS_SHARD : expr := #4.

Definition KV_MOV_SHARD : expr := #5.

Definition shardOf: val :=
  rec: "shardOf" "key" :=
    "key" `rem` NSHARD.

Definition bytesEqual: val :=
  rec: "bytesEqual" "x" "y" :=
    let: "xlen" := slice.len "x" in
    (if: "xlen" ≠ slice.len "y"
    then #false
    else
      let: "i" := ref_to uint64T #0 in
      let: "retval" := ref_to boolT #true in
      Skip;;
      (for: (λ: <>, ![uint64T] "i" < "xlen"); (λ: <>, Skip) := λ: <>,
        (if: SliceGet byteT "x" (![uint64T] "i") ≠ SliceGet byteT "y" (![uint64T] "i")
        then
          "retval" <-[boolT] #false;;
          Break
        else
          "i" <-[uint64T] ![uint64T] "i" + #1;;
          Continue));;
      ![boolT] "retval").

(* "universal" reply type for the reply table *)
Definition ShardReply := struct.decl [
  "Err" :: ErrorType;
  "Value" :: slice.T byteT;
  "Success" :: boolT
].

Definition PutRequest := struct.decl [
  "CID" :: uint64T;
  "Seq" :: uint64T;
  "Key" :: uint64T;
  "Value" :: slice.T byteT
].

(* doesn't include the operation type *)
Definition encodePutRequest: val :=
  rec: "encodePutRequest" "args" :=
    let: "num_bytes" := #8 + #8 + #8 + #8 + slice.len (struct.loadF PutRequest "Value" "args") in
    control.impl.Assume ("num_bytes" > slice.len (struct.loadF PutRequest "Value" "args"));;
    let: "e" := marshal.NewEnc "num_bytes" in
    marshal.Enc__PutInt "e" (struct.loadF PutRequest "CID" "args");;
    marshal.Enc__PutInt "e" (struct.loadF PutRequest "Seq" "args");;
    marshal.Enc__PutInt "e" (struct.loadF PutRequest "Key" "args");;
    marshal.Enc__PutInt "e" (slice.len (struct.loadF PutRequest "Value" "args"));;
    marshal.Enc__PutBytes "e" (struct.loadF PutRequest "Value" "args");;
    marshal.Enc__Finish "e".

Definition decodePutRequest: val :=
  rec: "decodePutRequest" "reqData" :=
    let: "req" := struct.alloc PutRequest (zero_val (struct.t PutRequest)) in
    let: "d" := marshal.NewDec "reqData" in
    struct.storeF PutRequest "CID" "req" (marshal.Dec__GetInt "d");;
    struct.storeF PutRequest "Seq" "req" (marshal.Dec__GetInt "d");;
    struct.storeF PutRequest "Key" "req" (marshal.Dec__GetInt "d");;
    struct.storeF PutRequest "Value" "req" (marshal.Dec__GetBytes "d" (marshal.Dec__GetInt "d"));;
    "req".

Definition PutReply := struct.decl [
  "Err" :: ErrorType
].

Definition encodePutReply: val :=
  rec: "encodePutReply" "reply" :=
    let: "e" := marshal.NewEnc #8 in
    marshal.Enc__PutInt "e" (struct.loadF PutReply "Err" "reply");;
    marshal.Enc__Finish "e".

Definition decodePutReply: val :=
  rec: "decodePutReply" "replyData" :=
    let: "reply" := struct.alloc PutReply (zero_val (struct.t PutReply)) in
    let: "d" := marshal.NewDec "replyData" in
    struct.storeF PutReply "Err" "reply" (marshal.Dec__GetInt "d");;
    "reply".

Definition GetRequest := struct.decl [
  "CID" :: uint64T;
  "Seq" :: uint64T;
  "Key" :: uint64T
].

Definition GetReply := struct.decl [
  "Err" :: ErrorType;
  "Value" :: slice.T byteT
].

Definition encodeGetRequest: val :=
  rec: "encodeGetRequest" "req" :=
    let: "e" := marshal.NewEnc (#3 * #8) in
    marshal.Enc__PutInt "e" (struct.loadF GetRequest "CID" "req");;
    marshal.Enc__PutInt "e" (struct.loadF GetRequest "Seq" "req");;
    marshal.Enc__PutInt "e" (struct.loadF GetRequest "Key" "req");;
    marshal.Enc__Finish "e".

Definition decodeGetRequest: val :=
  rec: "decodeGetRequest" "rawReq" :=
    let: "req" := struct.alloc GetRequest (zero_val (struct.t GetRequest)) in
    let: "d" := marshal.NewDec "rawReq" in
    struct.storeF GetRequest "CID" "req" (marshal.Dec__GetInt "d");;
    struct.storeF GetRequest "Seq" "req" (marshal.Dec__GetInt "d");;
    struct.storeF GetRequest "Key" "req" (marshal.Dec__GetInt "d");;
    "req".

Definition encodeGetReply: val :=
  rec: "encodeGetReply" "rep" :=
    let: "num_bytes" := #8 + #8 + slice.len (struct.loadF GetReply "Value" "rep") in
    control.impl.Assume ("num_bytes" > slice.len (struct.loadF GetReply "Value" "rep"));;
    let: "e" := marshal.NewEnc "num_bytes" in
    marshal.Enc__PutInt "e" (struct.loadF GetReply "Err" "rep");;
    marshal.Enc__PutInt "e" (slice.len (struct.loadF GetReply "Value" "rep"));;
    marshal.Enc__PutBytes "e" (struct.loadF GetReply "Value" "rep");;
    marshal.Enc__Finish "e".

Definition decodeGetReply: val :=
  rec: "decodeGetReply" "rawRep" :=
    let: "rep" := struct.alloc GetReply (zero_val (struct.t GetReply)) in
    let: "d" := marshal.NewDec "rawRep" in
    struct.storeF GetReply "Err" "rep" (marshal.Dec__GetInt "d");;
    struct.storeF GetReply "Value" "rep" (marshal.Dec__GetBytes "d" (marshal.Dec__GetInt "d"));;
    "rep".

Definition ConditionalPutRequest := struct.decl [
  "CID" :: uint64T;
  "Seq" :: uint64T;
  "Key" :: uint64T;
  "ExpectedValue" :: slice.T byteT;
  "NewValue" :: slice.T byteT
].

Definition ConditionalPutReply := struct.decl [
  "Err" :: ErrorType;
  "Success" :: boolT
].

Definition encodeConditionalPutRequest: val :=
  rec: "encodeConditionalPutRequest" "req" :=
    control.impl.Assume (slice.len (struct.loadF ConditionalPutRequest "ExpectedValue" "req") + slice.len (struct.loadF ConditionalPutRequest "NewValue" "req") > slice.len (struct.loadF ConditionalPutRequest "ExpectedValue" "req"));;
    let: "num_bytes" := #8 + #8 + #8 + #8 + #8 + slice.len (struct.loadF ConditionalPutRequest "ExpectedValue" "req") + slice.len (struct.loadF ConditionalPutRequest "NewValue" "req") in
    control.impl.Assume ("num_bytes" > slice.len (struct.loadF ConditionalPutRequest "ExpectedValue" "req") + slice.len (struct.loadF ConditionalPutRequest "NewValue" "req"));;
    let: "e" := marshal.NewEnc "num_bytes" in
    marshal.Enc__PutInt "e" (struct.loadF ConditionalPutRequest "CID" "req");;
    marshal.Enc__PutInt "e" (struct.loadF ConditionalPutRequest "Seq" "req");;
    marshal.Enc__PutInt "e" (struct.loadF ConditionalPutRequest "Key" "req");;
    marshal.Enc__PutInt "e" (slice.len (struct.loadF ConditionalPutRequest "ExpectedValue" "req"));;
    marshal.Enc__PutBytes "e" (struct.loadF ConditionalPutRequest "ExpectedValue" "req");;
    marshal.Enc__PutInt "e" (slice.len (struct.loadF ConditionalPutRequest "NewValue" "req"));;
    marshal.Enc__PutBytes "e" (struct.loadF ConditionalPutRequest "NewValue" "req");;
    marshal.Enc__Finish "e".

Definition decodeConditionalPutRequest: val :=
  rec: "decodeConditionalPutRequest" "rawReq" :=
    let: "req" := struct.alloc ConditionalPutRequest (zero_val (struct.t ConditionalPutRequest)) in
    let: "d" := marshal.NewDec "rawReq" in
    struct.storeF ConditionalPutRequest "CID" "req" (marshal.Dec__GetInt "d");;
    struct.storeF ConditionalPutRequest "Seq" "req" (marshal.Dec__GetInt "d");;
    struct.storeF ConditionalPutRequest "Key" "req" (marshal.Dec__GetInt "d");;
    struct.storeF ConditionalPutRequest "ExpectedValue" "req" (marshal.Dec__GetBytes "d" (marshal.Dec__GetInt "d"));;
    struct.storeF ConditionalPutRequest "NewValue" "req" (marshal.Dec__GetBytes "d" (marshal.Dec__GetInt "d"));;
    "req".

Definition encodeConditionalPutReply: val :=
  rec: "encodeConditionalPutReply" "reply" :=
    let: "e" := marshal.NewEnc (#8 + #1) in
    marshal.Enc__PutInt "e" (struct.loadF ConditionalPutReply "Err" "reply");;
    marshal.Enc__PutBool "e" (struct.loadF ConditionalPutReply "Success" "reply");;
    marshal.Enc__Finish "e".

Definition decodeConditionalPutReply: val :=
  rec: "decodeConditionalPutReply" "replyData" :=
    let: "reply" := struct.alloc ConditionalPutReply (zero_val (struct.t ConditionalPutReply)) in
    let: "d" := marshal.NewDec "replyData" in
    struct.storeF ConditionalPutReply "Err" "reply" (marshal.Dec__GetInt "d");;
    struct.storeF ConditionalPutReply "Success" "reply" (marshal.Dec__GetBool "d");;
    "reply".

Definition InstallShardRequest := struct.decl [
  "CID" :: uint64T;
  "Seq" :: uint64T;
  "Sid" :: uint64T;
  "Kvs" :: mapT (slice.T byteT)
].

(* NOTE: probably can just amortize this by keeping track of this with the map itself *)
Definition SizeOfMarshalledMap: val :=
  rec: "SizeOfMarshalledMap" "m" :=
    let: "s" := ref (zero_val uint64T) in
    "s" <-[uint64T] #8;;
    MapIter "m" (λ: <> "value",
      "s" <-[uint64T] ![uint64T] "s" + slice.len "value" + #8 + #8);;
    ![uint64T] "s".

Definition EncSliceMap: val :=
  rec: "EncSliceMap" "e" "m" :=
    marshal.Enc__PutInt "e" (MapLen "m");;
    MapIter "m" (λ: "key" "value",
      marshal.Enc__PutInt "e" "key";;
      marshal.Enc__PutInt "e" (slice.len "value");;
      marshal.Enc__PutBytes "e" "value").

Definition DecSliceMap: val :=
  rec: "DecSliceMap" "d" :=
    let: "sz" := marshal.Dec__GetInt "d" in
    let: "m" := NewMap (slice.T byteT) in
    let: "i" := ref_to uint64T #0 in
    Skip;;
    (for: (λ: <>, ![uint64T] "i" < "sz"); (λ: <>, Skip) := λ: <>,
      let: "k" := marshal.Dec__GetInt "d" in
      let: "v" := marshal.Dec__GetBytes "d" (marshal.Dec__GetInt "d") in
      MapInsert "m" "k" "v";;
      "i" <-[uint64T] ![uint64T] "i" + #1;;
      Continue);;
    "m".

Definition encodeInstallShardRequest: val :=
  rec: "encodeInstallShardRequest" "req" :=
    let: "e" := marshal.NewEnc (#8 + #8 + #8 + SizeOfMarshalledMap (struct.loadF InstallShardRequest "Kvs" "req")) in
    marshal.Enc__PutInt "e" (struct.loadF InstallShardRequest "CID" "req");;
    marshal.Enc__PutInt "e" (struct.loadF InstallShardRequest "Seq" "req");;
    marshal.Enc__PutInt "e" (struct.loadF InstallShardRequest "Sid" "req");;
    EncSliceMap "e" (struct.loadF InstallShardRequest "Kvs" "req");;
    marshal.Enc__Finish "e".

Definition decodeInstallShardRequest: val :=
  rec: "decodeInstallShardRequest" "rawReq" :=
    let: "d" := marshal.NewDec "rawReq" in
    let: "req" := struct.alloc InstallShardRequest (zero_val (struct.t InstallShardRequest)) in
    struct.storeF InstallShardRequest "CID" "req" (marshal.Dec__GetInt "d");;
    struct.storeF InstallShardRequest "Seq" "req" (marshal.Dec__GetInt "d");;
    struct.storeF InstallShardRequest "Sid" "req" (marshal.Dec__GetInt "d");;
    struct.storeF InstallShardRequest "Kvs" "req" (DecSliceMap "d");;
    "req".

Definition MoveShardRequest := struct.decl [
  "Sid" :: uint64T;
  "Dst" :: HostName
].

Definition encodeMoveShardRequest: val :=
  rec: "encodeMoveShardRequest" "req" :=
    let: "e" := marshal.NewEnc (#8 + #8) in
    marshal.Enc__PutInt "e" (struct.loadF MoveShardRequest "Sid" "req");;
    marshal.Enc__PutInt "e" (struct.loadF MoveShardRequest "Dst" "req");;
    marshal.Enc__Finish "e".

Definition decodeMoveShardRequest: val :=
  rec: "decodeMoveShardRequest" "rawReq" :=
    let: "req" := struct.alloc MoveShardRequest (zero_val (struct.t MoveShardRequest)) in
    let: "d" := marshal.NewDec "rawReq" in
    struct.storeF MoveShardRequest "Sid" "req" (marshal.Dec__GetInt "d");;
    struct.storeF MoveShardRequest "Dst" "req" (marshal.Dec__GetInt "d");;
    "req".

Definition encodeUint64: val :=
  rec: "encodeUint64" "i" :=
    let: "e" := marshal.NewEnc #8 in
    marshal.Enc__PutInt "e" "i";;
    marshal.Enc__Finish "e".

Definition decodeUint64: val :=
  rec: "decodeUint64" "raw" :=
    marshal.Dec__GetInt (marshal.NewDec "raw").

Definition encodeShardMap: val :=
  rec: "encodeShardMap" "shardMap" :=
    let: "e" := marshal.NewEnc (#8 * NSHARD) in
    marshal.Enc__PutInts "e" (![slice.T uint64T] "shardMap");;
    marshal.Enc__Finish "e".

Definition decodeShardMap: val :=
  rec: "decodeShardMap" "raw" :=
    let: "d" := marshal.NewDec "raw" in
    marshal.Dec__GetInts "d" NSHARD.

(* 1_memkv_shard_clerk.go *)

Definition MemKVShardClerk := struct.decl [
  "seq" :: uint64T;
  "cid" :: uint64T;
  "cl" :: struct.ptrT rpc.RPCClient
].

Definition MakeFreshKVClerk: val :=
  rec: "MakeFreshKVClerk" "host" :=
    let: "ck" := struct.alloc MemKVShardClerk (zero_val (struct.t MemKVShardClerk)) in
    struct.storeF MemKVShardClerk "cl" "ck" (rpc.MakeRPCClient "host");;
    let: "rawRep" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, (rpc.RPCClient__Call (struct.loadF MemKVShardClerk "cl" "ck") KV_FRESHCID (NewSlice byteT #0) "rawRep" = #true)); (λ: <>, Skip) := λ: <>,
      Continue);;
    struct.storeF MemKVShardClerk "cid" "ck" (decodeUint64 (![slice.T byteT] "rawRep"));;
    struct.storeF MemKVShardClerk "seq" "ck" #1;;
    "ck".

Definition MemKVShardClerk__Put: val :=
  rec: "MemKVShardClerk__Put" "ck" "key" "value" :=
    let: "args" := struct.alloc PutRequest (zero_val (struct.t PutRequest)) in
    struct.storeF PutRequest "CID" "args" (struct.loadF MemKVShardClerk "cid" "ck");;
    struct.storeF PutRequest "Seq" "args" (struct.loadF MemKVShardClerk "seq" "ck");;
    struct.storeF PutRequest "Key" "args" "key";;
    struct.storeF PutRequest "Value" "args" "value";;
    control.impl.Assume (struct.loadF MemKVShardClerk "seq" "ck" + #1 > struct.loadF MemKVShardClerk "seq" "ck");;
    struct.storeF MemKVShardClerk "seq" "ck" (struct.loadF MemKVShardClerk "seq" "ck" + #1);;
    let: "rawRep" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, (rpc.RPCClient__Call (struct.loadF MemKVShardClerk "cl" "ck") KV_PUT (encodePutRequest "args") "rawRep" = #true)); (λ: <>, Skip) := λ: <>,
      Continue);;
    let: "rep" := decodePutReply (![slice.T byteT] "rawRep") in
    struct.loadF PutReply "Err" "rep".

Definition MemKVShardClerk__Get: val :=
  rec: "MemKVShardClerk__Get" "ck" "key" "value" :=
    let: "args" := struct.alloc GetRequest (zero_val (struct.t GetRequest)) in
    struct.storeF GetRequest "CID" "args" (struct.loadF MemKVShardClerk "cid" "ck");;
    struct.storeF GetRequest "Seq" "args" (struct.loadF MemKVShardClerk "seq" "ck");;
    struct.storeF GetRequest "Key" "args" "key";;
    control.impl.Assume (struct.loadF MemKVShardClerk "seq" "ck" + #1 > struct.loadF MemKVShardClerk "seq" "ck");;
    struct.storeF MemKVShardClerk "seq" "ck" (struct.loadF MemKVShardClerk "seq" "ck" + #1);;
    let: "rawRep" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, (rpc.RPCClient__Call (struct.loadF MemKVShardClerk "cl" "ck") KV_GET (encodeGetRequest "args") "rawRep" = #true)); (λ: <>, Skip) := λ: <>,
      Continue);;
    let: "rep" := decodeGetReply (![slice.T byteT] "rawRep") in
    "value" <-[slice.T byteT] struct.loadF GetReply "Value" "rep";;
    struct.loadF GetReply "Err" "rep".

Definition MemKVShardClerk__ConditionalPut: val :=
  rec: "MemKVShardClerk__ConditionalPut" "ck" "key" "expectedValue" "newValue" "success" :=
    let: "args" := struct.alloc ConditionalPutRequest (zero_val (struct.t ConditionalPutRequest)) in
    struct.storeF ConditionalPutRequest "CID" "args" (struct.loadF MemKVShardClerk "cid" "ck");;
    struct.storeF ConditionalPutRequest "Seq" "args" (struct.loadF MemKVShardClerk "seq" "ck");;
    struct.storeF ConditionalPutRequest "Key" "args" "key";;
    struct.storeF ConditionalPutRequest "ExpectedValue" "args" "expectedValue";;
    struct.storeF ConditionalPutRequest "NewValue" "args" "newValue";;
    control.impl.Assume (struct.loadF MemKVShardClerk "seq" "ck" + #1 > struct.loadF MemKVShardClerk "seq" "ck");;
    struct.storeF MemKVShardClerk "seq" "ck" (struct.loadF MemKVShardClerk "seq" "ck" + #1);;
    let: "rawRep" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, (rpc.RPCClient__Call (struct.loadF MemKVShardClerk "cl" "ck") KV_CONDITIONAL_PUT (encodeConditionalPutRequest "args") "rawRep" = #true)); (λ: <>, Skip) := λ: <>,
      Continue);;
    let: "rep" := decodeConditionalPutReply (![slice.T byteT] "rawRep") in
    "success" <-[boolT] struct.loadF ConditionalPutReply "Success" "rep";;
    struct.loadF ConditionalPutReply "Err" "rep".

Definition MemKVShardClerk__InstallShard: val :=
  rec: "MemKVShardClerk__InstallShard" "ck" "sid" "kvs" :=
    let: "args" := struct.alloc InstallShardRequest (zero_val (struct.t InstallShardRequest)) in
    struct.storeF InstallShardRequest "CID" "args" (struct.loadF MemKVShardClerk "cid" "ck");;
    struct.storeF InstallShardRequest "Seq" "args" (struct.loadF MemKVShardClerk "seq" "ck");;
    struct.storeF InstallShardRequest "Sid" "args" "sid";;
    struct.storeF InstallShardRequest "Kvs" "args" "kvs";;
    control.impl.Assume (struct.loadF MemKVShardClerk "seq" "ck" + #1 > struct.loadF MemKVShardClerk "seq" "ck");;
    struct.storeF MemKVShardClerk "seq" "ck" (struct.loadF MemKVShardClerk "seq" "ck" + #1);;
    let: "rawRep" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, (rpc.RPCClient__Call (struct.loadF MemKVShardClerk "cl" "ck") KV_INS_SHARD (encodeInstallShardRequest "args") "rawRep" = #true)); (λ: <>, Skip) := λ: <>,
      Continue).

Definition MemKVShardClerk__MoveShard: val :=
  rec: "MemKVShardClerk__MoveShard" "ck" "sid" "dst" :=
    let: "args" := struct.alloc MoveShardRequest (zero_val (struct.t MoveShardRequest)) in
    struct.storeF MoveShardRequest "Sid" "args" "sid";;
    struct.storeF MoveShardRequest "Dst" "args" "dst";;
    let: "rawRep" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, (rpc.RPCClient__Call (struct.loadF MemKVShardClerk "cl" "ck") KV_MOV_SHARD (encodeMoveShardRequest "args") "rawRep" = #true)); (λ: <>, Skip) := λ: <>,
      Continue).

(* 2_memkv_shard.go *)

Definition KvMap: ty := mapT (slice.T byteT).

Definition MemKVShardServer := struct.decl [
  "me" :: stringT;
  "mu" :: lockRefT;
  "lastReply" :: mapT (struct.t ShardReply);
  "lastSeq" :: mapT uint64T;
  "nextCID" :: uint64T;
  "shardMap" :: slice.T boolT;
  "kvss" :: slice.T KvMap;
  "peers" :: mapT (struct.ptrT MemKVShardClerk)
].

Definition PutArgs := struct.decl [
  "Key" :: uint64T;
  "Value" :: ValueType
].

Definition MemKVShardServer__put_inner: val :=
  rec: "MemKVShardServer__put_inner" "s" "args" "reply" :=
    let: ("last", "ok") := MapGet (struct.loadF MemKVShardServer "lastSeq" "s") (struct.loadF PutRequest "CID" "args") in
    let: "seq" := struct.loadF PutRequest "Seq" "args" in
    (if: "ok" && ("seq" ≤ "last")
    then
      struct.storeF PutReply "Err" "reply" (struct.get ShardReply "Err" (Fst (MapGet (struct.loadF MemKVShardServer "lastReply" "s") (struct.loadF PutRequest "CID" "args"))));;
      #()
    else
      MapInsert (struct.loadF MemKVShardServer "lastSeq" "s") (struct.loadF PutRequest "CID" "args") (struct.loadF PutRequest "Seq" "args");;
      let: "sid" := shardOf (struct.loadF PutRequest "Key" "args") in
      (if: (SliceGet boolT (struct.loadF MemKVShardServer "shardMap" "s") "sid" = #true)
      then
        MapInsert (SliceGet (mapT (slice.T byteT)) (struct.loadF MemKVShardServer "kvss" "s") "sid") (struct.loadF PutRequest "Key" "args") (struct.loadF PutRequest "Value" "args");;
        struct.storeF PutReply "Err" "reply" ENone
      else struct.storeF PutReply "Err" "reply" EDontHaveShard);;
      MapInsert (struct.loadF MemKVShardServer "lastReply" "s") (struct.loadF PutRequest "CID" "args") (struct.mk ShardReply [
        "Err" ::= struct.loadF PutReply "Err" "reply"
      ])).

Definition MemKVShardServer__PutRPC: val :=
  rec: "MemKVShardServer__PutRPC" "s" "args" "reply" :=
    lock.acquire (struct.loadF MemKVShardServer "mu" "s");;
    MemKVShardServer__put_inner "s" "args" "reply";;
    lock.release (struct.loadF MemKVShardServer "mu" "s").

Definition MemKVShardServer__get_inner: val :=
  rec: "MemKVShardServer__get_inner" "s" "args" "reply" :=
    let: ("last", "ok") := MapGet (struct.loadF MemKVShardServer "lastSeq" "s") (struct.loadF GetRequest "CID" "args") in
    let: "seq" := struct.loadF GetRequest "Seq" "args" in
    (if: "ok" && ("seq" ≤ "last")
    then
      let: "lastReply" := Fst (MapGet (struct.loadF MemKVShardServer "lastReply" "s") (struct.loadF GetRequest "CID" "args")) in
      struct.storeF GetReply "Err" "reply" (struct.get ShardReply "Err" "lastReply");;
      struct.storeF GetReply "Value" "reply" (struct.get ShardReply "Value" "lastReply");;
      #()
    else
      MapInsert (struct.loadF MemKVShardServer "lastSeq" "s") (struct.loadF GetRequest "CID" "args") (struct.loadF GetRequest "Seq" "args");;
      let: "sid" := shardOf (struct.loadF GetRequest "Key" "args") in
      (if: (SliceGet boolT (struct.loadF MemKVShardServer "shardMap" "s") "sid" = #true)
      then
        struct.storeF GetReply "Value" "reply" (Fst (MapGet (SliceGet (mapT (slice.T byteT)) (struct.loadF MemKVShardServer "kvss" "s") "sid") (struct.loadF GetRequest "Key" "args")));;
        struct.storeF GetReply "Err" "reply" ENone
      else struct.storeF GetReply "Err" "reply" EDontHaveShard);;
      MapInsert (struct.loadF MemKVShardServer "lastReply" "s") (struct.loadF GetRequest "CID" "args") (struct.mk ShardReply [
        "Err" ::= struct.loadF GetReply "Err" "reply";
        "Value" ::= struct.loadF GetReply "Value" "reply"
      ])).

Definition MemKVShardServer__GetRPC: val :=
  rec: "MemKVShardServer__GetRPC" "s" "args" "reply" :=
    lock.acquire (struct.loadF MemKVShardServer "mu" "s");;
    MemKVShardServer__get_inner "s" "args" "reply";;
    lock.release (struct.loadF MemKVShardServer "mu" "s").

Definition MemKVShardServer__conditional_put_inner: val :=
  rec: "MemKVShardServer__conditional_put_inner" "s" "args" "reply" :=
    let: ("last", "ok") := MapGet (struct.loadF MemKVShardServer "lastSeq" "s") (struct.loadF ConditionalPutRequest "CID" "args") in
    let: "seq" := struct.loadF ConditionalPutRequest "Seq" "args" in
    (if: "ok" && ("seq" ≤ "last")
    then
      let: "lastReply" := Fst (MapGet (struct.loadF MemKVShardServer "lastReply" "s") (struct.loadF ConditionalPutRequest "CID" "args")) in
      struct.storeF ConditionalPutReply "Err" "reply" (struct.get ShardReply "Err" "lastReply");;
      struct.storeF ConditionalPutReply "Success" "reply" (struct.get ShardReply "Success" "lastReply");;
      #()
    else
      MapInsert (struct.loadF MemKVShardServer "lastSeq" "s") (struct.loadF ConditionalPutRequest "CID" "args") (struct.loadF ConditionalPutRequest "Seq" "args");;
      let: "sid" := shardOf (struct.loadF ConditionalPutRequest "Key" "args") in
      (if: (SliceGet boolT (struct.loadF MemKVShardServer "shardMap" "s") "sid" = #true)
      then
        let: "m" := SliceGet (mapT (slice.T byteT)) (struct.loadF MemKVShardServer "kvss" "s") "sid" in
        let: "equal" := bytesEqual (struct.loadF ConditionalPutRequest "ExpectedValue" "args") (Fst (MapGet "m" (struct.loadF ConditionalPutRequest "Key" "args"))) in
        (if: "equal"
        then
          MapInsert "m" (struct.loadF ConditionalPutRequest "Key" "args") (struct.loadF ConditionalPutRequest "NewValue" "args");;
          #()
        else #());;
        struct.storeF ConditionalPutReply "Success" "reply" "equal";;
        struct.storeF ConditionalPutReply "Err" "reply" ENone
      else struct.storeF ConditionalPutReply "Err" "reply" EDontHaveShard);;
      MapInsert (struct.loadF MemKVShardServer "lastReply" "s") (struct.loadF ConditionalPutRequest "CID" "args") (struct.mk ShardReply [
        "Err" ::= struct.loadF ConditionalPutReply "Err" "reply";
        "Success" ::= struct.loadF ConditionalPutReply "Success" "reply"
      ])).

Definition MemKVShardServer__ConditionalPutRPC: val :=
  rec: "MemKVShardServer__ConditionalPutRPC" "s" "args" "reply" :=
    lock.acquire (struct.loadF MemKVShardServer "mu" "s");;
    MemKVShardServer__conditional_put_inner "s" "args" "reply";;
    lock.release (struct.loadF MemKVShardServer "mu" "s").

(* NOTE: easy to do a little optimization with shard migration:
   add a "RemoveShard" rpc, which removes the shard on the target server, and
   returns half of the ghost state for that shard. Meanwhile, InstallShard()
   will only grant half the ghost state, and physical state will keep track of
   the fact that the shard is only good for read-only operations up until that
   flag is updated (i.e. until RemoveShard() is run). *)
Definition MemKVShardServer__install_shard_inner: val :=
  rec: "MemKVShardServer__install_shard_inner" "s" "args" :=
    let: ("last", "ok") := MapGet (struct.loadF MemKVShardServer "lastSeq" "s") (struct.loadF InstallShardRequest "CID" "args") in
    let: "seq" := struct.loadF InstallShardRequest "Seq" "args" in
    (if: "ok" && ("seq" ≤ "last")
    then #()
    else
      MapInsert (struct.loadF MemKVShardServer "lastSeq" "s") (struct.loadF InstallShardRequest "CID" "args") (struct.loadF InstallShardRequest "Seq" "args");;
      SliceSet boolT (struct.loadF MemKVShardServer "shardMap" "s") (struct.loadF InstallShardRequest "Sid" "args") #true;;
      SliceSet (mapT (slice.T byteT)) (struct.loadF MemKVShardServer "kvss" "s") (struct.loadF InstallShardRequest "Sid" "args") (struct.loadF InstallShardRequest "Kvs" "args");;
      MapInsert (struct.loadF MemKVShardServer "lastReply" "s") (struct.loadF InstallShardRequest "CID" "args") (struct.mk ShardReply [
        "Err" ::= #0;
        "Value" ::= slice.nil
      ])).

Definition MemKVShardServer__InstallShardRPC: val :=
  rec: "MemKVShardServer__InstallShardRPC" "s" "args" :=
    lock.acquire (struct.loadF MemKVShardServer "mu" "s");;
    MemKVShardServer__install_shard_inner "s" "args";;
    lock.release (struct.loadF MemKVShardServer "mu" "s").

Definition MemKVShardServer__MoveShardRPC: val :=
  rec: "MemKVShardServer__MoveShardRPC" "s" "args" :=
    lock.acquire (struct.loadF MemKVShardServer "mu" "s");;
    let: (<>, "ok") := MapGet (struct.loadF MemKVShardServer "peers" "s") (struct.loadF MoveShardRequest "Dst" "args") in
    (if: ~ "ok"
    then
      let: "ck" := MakeFreshKVClerk (struct.loadF MoveShardRequest "Dst" "args") in
      MapInsert (struct.loadF MemKVShardServer "peers" "s") (struct.loadF MoveShardRequest "Dst" "args") "ck";;
      #()
    else #());;
    (if: ~ (SliceGet boolT (struct.loadF MemKVShardServer "shardMap" "s") (struct.loadF MoveShardRequest "Sid" "args"))
    then
      lock.release (struct.loadF MemKVShardServer "mu" "s");;
      #()
    else
      let: "kvs" := SliceGet (mapT (slice.T byteT)) (struct.loadF MemKVShardServer "kvss" "s") (struct.loadF MoveShardRequest "Sid" "args") in
      SliceSet (mapT (slice.T byteT)) (struct.loadF MemKVShardServer "kvss" "s") (struct.loadF MoveShardRequest "Sid" "args") (NewMap (slice.T byteT));;
      SliceSet boolT (struct.loadF MemKVShardServer "shardMap" "s") (struct.loadF MoveShardRequest "Sid" "args") #false;;
      MemKVShardClerk__InstallShard (Fst (MapGet (struct.loadF MemKVShardServer "peers" "s") (struct.loadF MoveShardRequest "Dst" "args"))) (struct.loadF MoveShardRequest "Sid" "args") "kvs";;
      lock.release (struct.loadF MemKVShardServer "mu" "s")).

Definition MakeMemKVShardServer: val :=
  rec: "MakeMemKVShardServer" "is_init" :=
    let: "srv" := struct.alloc MemKVShardServer (zero_val (struct.t MemKVShardServer)) in
    struct.storeF MemKVShardServer "mu" "srv" (lock.new #());;
    struct.storeF MemKVShardServer "lastReply" "srv" (NewMap (struct.t ShardReply));;
    struct.storeF MemKVShardServer "lastSeq" "srv" (NewMap uint64T);;
    struct.storeF MemKVShardServer "shardMap" "srv" (NewSlice boolT NSHARD);;
    struct.storeF MemKVShardServer "kvss" "srv" (NewSlice KvMap NSHARD);;
    struct.storeF MemKVShardServer "peers" "srv" (NewMap (struct.ptrT MemKVShardClerk));;
    let: "i" := ref_to uint64T #0 in
    (for: (λ: <>, ![uint64T] "i" < NSHARD); (λ: <>, "i" <-[uint64T] ![uint64T] "i" + #1) := λ: <>,
      SliceSet boolT (struct.loadF MemKVShardServer "shardMap" "srv") (![uint64T] "i") "is_init";;
      (if: "is_init"
      then SliceSet (mapT (slice.T byteT)) (struct.loadF MemKVShardServer "kvss" "srv") (![uint64T] "i") (NewMap (slice.T byteT))
      else #());;
      Continue);;
    "srv".

Definition MemKVShardServer__GetCIDRPC: val :=
  rec: "MemKVShardServer__GetCIDRPC" "s" :=
    (* log.Println("GetCIDRPC() starting") *)
    lock.acquire (struct.loadF MemKVShardServer "mu" "s");;
    let: "r" := struct.loadF MemKVShardServer "nextCID" "s" in
    control.impl.Assume (struct.loadF MemKVShardServer "nextCID" "s" + #1 > struct.loadF MemKVShardServer "nextCID" "s");;
    struct.storeF MemKVShardServer "nextCID" "s" (struct.loadF MemKVShardServer "nextCID" "s" + #1);;
    lock.release (struct.loadF MemKVShardServer "mu" "s");;
    (* log.Println("GetCIDRPC() done") *)
    "r".

Definition MemKVShardServer__Start: val :=
  rec: "MemKVShardServer__Start" "mkv" "host" :=
    let: "handlers" := NewMap ((slice.T byteT -> refT (slice.T byteT) -> unitT)%ht) in
    MapInsert "handlers" KV_FRESHCID (λ: "rawReq" "rawReply",
      "rawReply" <-[slice.T byteT] encodeUint64 (MemKVShardServer__GetCIDRPC "mkv")
      );;
    MapInsert "handlers" KV_PUT (λ: "rawReq" "rawReply",
      let: "rep" := struct.alloc PutReply (zero_val (struct.t PutReply)) in
      MemKVShardServer__PutRPC "mkv" (decodePutRequest "rawReq") "rep";;
      "rawReply" <-[slice.T byteT] encodePutReply "rep"
      );;
    MapInsert "handlers" KV_GET (λ: "rawReq" "rawReply",
      let: "rep" := struct.alloc GetReply (zero_val (struct.t GetReply)) in
      MemKVShardServer__GetRPC "mkv" (decodeGetRequest "rawReq") "rep";;
      "rawReply" <-[slice.T byteT] encodeGetReply "rep"
      );;
    MapInsert "handlers" KV_CONDITIONAL_PUT (λ: "rawReq" "rawReply",
      let: "rep" := struct.alloc ConditionalPutReply (zero_val (struct.t ConditionalPutReply)) in
      MemKVShardServer__ConditionalPutRPC "mkv" (decodeConditionalPutRequest "rawReq") "rep";;
      "rawReply" <-[slice.T byteT] encodeConditionalPutReply "rep"
      );;
    MapInsert "handlers" KV_INS_SHARD (λ: "rawReq" "rawReply",
      MemKVShardServer__InstallShardRPC "mkv" (decodeInstallShardRequest "rawReq");;
      "rawReply" <-[slice.T byteT] NewSlice byteT #0
      );;
    MapInsert "handlers" KV_MOV_SHARD (λ: "rawReq" "rawReply",
      MemKVShardServer__MoveShardRPC "mkv" (decodeMoveShardRequest "rawReq");;
      "rawReply" <-[slice.T byteT] NewSlice byteT #0
      );;
    let: "s" := rpc.MakeRPCServer "handlers" in
    rpc.RPCServer__Serve "s" "host" #1.

(* 3_memkv_coord.go *)

Definition COORD_ADD : expr := #1.

Definition COORD_GET : expr := #2.

Definition ShardClerkSet := struct.decl [
  "cls" :: mapT (struct.ptrT MemKVShardClerk)
].

Definition MakeShardClerkSet: val :=
  rec: "MakeShardClerkSet" <> :=
    struct.new ShardClerkSet [
      "cls" ::= NewMap (struct.ptrT MemKVShardClerk)
    ].

Definition ShardClerkSet__GetClerk: val :=
  rec: "ShardClerkSet__GetClerk" "s" "host" :=
    let: ("ck", "ok") := MapGet (struct.loadF ShardClerkSet "cls" "s") "host" in
    (if: ~ "ok"
    then
      let: "ck2" := MakeFreshKVClerk "host" in
      MapInsert (struct.loadF ShardClerkSet "cls" "s") "host" "ck2";;
      "ck2"
    else "ck").

Definition MemKVCoord := struct.decl [
  "mu" :: lockRefT;
  "config" :: mapT stringT;
  "shardMap" :: slice.T HostName;
  "hostShards" :: mapT uint64T;
  "shardClerks" :: struct.ptrT ShardClerkSet
].

Definition MemKVCoord__AddServerRPC: val :=
  rec: "MemKVCoord__AddServerRPC" "c" "newhost" :=
    lock.acquire (struct.loadF MemKVCoord "mu" "c");;
    (* log.Printf("Rebalancing\n") *)
    MapInsert (struct.loadF MemKVCoord "hostShards" "c") "newhost" #0;;
    let: "numHosts" := MapLen (struct.loadF MemKVCoord "hostShards" "c") in
    let: "numShardFloor" := NSHARD `quot` "numHosts" in
    let: "numShardCeil" := NSHARD `quot` "numHosts" + #1 in
    let: "nf_left" := ref (zero_val uint64T) in
    "nf_left" <-[uint64T] "numHosts" - NSHARD - ("numHosts" * NSHARD) `quot` "numHosts";;
    ForSlice uint64T "sid" "host" (struct.loadF MemKVCoord "shardMap" "c")
      (let: "n" := Fst (MapGet (struct.loadF MemKVCoord "hostShards" "c") "host") in
      (if: "n" > "numShardFloor"
      then
        (if: ("n" = "numShardCeil")
        then
          (if: ![uint64T] "nf_left" > #0
          then
            "nf_left" <-[uint64T] ![uint64T] "nf_left" - #1;;
            (* log.Printf("Moving %d from %s -> %s", sid, host, newhost) *)
            MemKVShardClerk__MoveShard (ShardClerkSet__GetClerk (struct.loadF MemKVCoord "shardClerks" "c") "host") "sid" "newhost";;
            MapInsert (struct.loadF MemKVCoord "hostShards" "c") "host" ("n" - #1);;
            MapInsert (struct.loadF MemKVCoord "hostShards" "c") "newhost" (Fst (MapGet (struct.loadF MemKVCoord "hostShards" "c") "newhost") + #1);;
            SliceSet uint64T (struct.loadF MemKVCoord "shardMap" "c") "sid" "newhost"
          else #())
        else
          (* log.Printf("Moving %d from %s -> %s", sid, host, newhost) *)
          MemKVShardClerk__MoveShard (ShardClerkSet__GetClerk (struct.loadF MemKVCoord "shardClerks" "c") "host") "sid" "newhost";;
          MapInsert (struct.loadF MemKVCoord "hostShards" "c") "host" ("n" - #1);;
          MapInsert (struct.loadF MemKVCoord "hostShards" "c") "newhost" (Fst (MapGet (struct.loadF MemKVCoord "hostShards" "c") "newhost") + #1);;
          SliceSet uint64T (struct.loadF MemKVCoord "shardMap" "c") "sid" "newhost")
      else #()));;
    (* log.Println("Done rebalancing") *)
    (* log.Printf("%+v", c.hostShards) *)
    lock.release (struct.loadF MemKVCoord "mu" "c").

Definition MemKVCoord__GetShardMapRPC: val :=
  rec: "MemKVCoord__GetShardMapRPC" "c" <> "rep" :=
    lock.acquire (struct.loadF MemKVCoord "mu" "c");;
    "rep" <-[slice.T byteT] encodeShardMap (struct.fieldRef MemKVCoord "shardMap" "c");;
    lock.release (struct.loadF MemKVCoord "mu" "c").

Definition MakeMemKVCoordServer: val :=
  rec: "MakeMemKVCoordServer" "initserver" :=
    let: "s" := struct.alloc MemKVCoord (zero_val (struct.t MemKVCoord)) in
    struct.storeF MemKVCoord "mu" "s" (lock.new #());;
    struct.storeF MemKVCoord "shardMap" "s" (NewSlice HostName NSHARD);;
    let: "i" := ref_to uint64T #0 in
    (for: (λ: <>, ![uint64T] "i" < NSHARD); (λ: <>, "i" <-[uint64T] ![uint64T] "i" + #1) := λ: <>,
      SliceSet uint64T (struct.loadF MemKVCoord "shardMap" "s") (![uint64T] "i") "initserver";;
      Continue);;
    struct.storeF MemKVCoord "hostShards" "s" (NewMap uint64T);;
    MapInsert (struct.loadF MemKVCoord "hostShards" "s") "initserver" NSHARD;;
    struct.storeF MemKVCoord "shardClerks" "s" (MakeShardClerkSet #());;
    "s".

Definition MemKVCoord__Start: val :=
  rec: "MemKVCoord__Start" "c" "host" :=
    let: "handlers" := NewMap ((slice.T byteT -> refT (slice.T byteT) -> unitT)%ht) in
    MapInsert "handlers" COORD_ADD (λ: "rawReq" "rawRep",
      let: "s" := decodeUint64 "rawReq" in
      MemKVCoord__AddServerRPC "c" "s"
      );;
    MapInsert "handlers" COORD_GET (MemKVCoord__GetShardMapRPC "c");;
    let: "s" := rpc.MakeRPCServer "handlers" in
    rpc.RPCServer__Serve "s" "host" #1.

(* memkv_clerk.go *)

Definition MemKVCoordClerk := struct.decl [
  "cl" :: struct.ptrT rpc.RPCClient
].

Definition MemKVCoordClerk__AddShardServer: val :=
  rec: "MemKVCoordClerk__AddShardServer" "ck" "dst" :=
    let: "rawRep" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, (rpc.RPCClient__Call (struct.loadF MemKVCoordClerk "cl" "ck") COORD_ADD (encodeUint64 "dst") "rawRep" = #true)); (λ: <>, Skip) := λ: <>,
      Continue);;
    #().

Definition MemKVCoordClerk__GetShardMap: val :=
  rec: "MemKVCoordClerk__GetShardMap" "ck" :=
    let: "rawRep" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, (rpc.RPCClient__Call (struct.loadF MemKVCoordClerk "cl" "ck") COORD_GET (NewSlice byteT #0) "rawRep" = #true)); (λ: <>, Skip) := λ: <>,
      Continue);;
    decodeShardMap (![slice.T byteT] "rawRep").

(* NOTE: a single clerk keeps quite a bit of state, via the shardMap[], so it
   might be good to not need to duplicate shardMap[] for a pool of clerks that's
   safe for concurrent use *)
Definition MemKVClerk := struct.decl [
  "shardClerks" :: struct.ptrT ShardClerkSet;
  "coordCk" :: struct.ptrT MemKVCoordClerk;
  "shardMap" :: slice.T HostName
].

Definition MemKVClerk__Get: val :=
  rec: "MemKVClerk__Get" "ck" "key" :=
    let: "val" := ref (zero_val (slice.T byteT)) in
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      let: "sid" := shardOf "key" in
      let: "shardServer" := SliceGet uint64T (struct.loadF MemKVClerk "shardMap" "ck") "sid" in
      let: "shardCk" := ShardClerkSet__GetClerk (struct.loadF MemKVClerk "shardClerks" "ck") "shardServer" in
      let: "err" := MemKVShardClerk__Get "shardCk" "key" "val" in
      (if: ("err" = ENone)
      then Break
      else
        struct.storeF MemKVClerk "shardMap" "ck" (MemKVCoordClerk__GetShardMap (struct.loadF MemKVClerk "coordCk" "ck"));;
        Continue));;
    ![slice.T byteT] "val".

Definition MemKVClerk__Put: val :=
  rec: "MemKVClerk__Put" "ck" "key" "value" :=
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      let: "sid" := shardOf "key" in
      let: "shardServer" := SliceGet uint64T (struct.loadF MemKVClerk "shardMap" "ck") "sid" in
      let: "shardCk" := ShardClerkSet__GetClerk (struct.loadF MemKVClerk "shardClerks" "ck") "shardServer" in
      let: "err" := MemKVShardClerk__Put "shardCk" "key" "value" in
      (if: ("err" = ENone)
      then Break
      else
        struct.storeF MemKVClerk "shardMap" "ck" (MemKVCoordClerk__GetShardMap (struct.loadF MemKVClerk "coordCk" "ck"));;
        Continue));;
    #().

Definition MemKVClerk__ConditionalPut: val :=
  rec: "MemKVClerk__ConditionalPut" "ck" "key" "expectedValue" "newValue" :=
    let: "success" := ref (zero_val boolT) in
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      let: "sid" := shardOf "key" in
      let: "shardServer" := SliceGet uint64T (struct.loadF MemKVClerk "shardMap" "ck") "sid" in
      let: "shardCk" := ShardClerkSet__GetClerk (struct.loadF MemKVClerk "shardClerks" "ck") "shardServer" in
      let: "err" := MemKVShardClerk__ConditionalPut "shardCk" "key" "expectedValue" "newValue" "success" in
      (if: ("err" = ENone)
      then Break
      else
        struct.storeF MemKVClerk "shardMap" "ck" (MemKVCoordClerk__GetShardMap (struct.loadF MemKVClerk "coordCk" "ck"));;
        Continue));;
    ![boolT] "success".

Definition MemKVClerk__Add: val :=
  rec: "MemKVClerk__Add" "ck" "host" :=
    MemKVCoordClerk__AddShardServer (struct.loadF MemKVClerk "coordCk" "ck") "host".

Definition MakeMemKVClerk: val :=
  rec: "MakeMemKVClerk" "coord" :=
    let: "cck" := struct.alloc MemKVCoordClerk (zero_val (struct.t MemKVCoordClerk)) in
    let: "ck" := struct.alloc MemKVClerk (zero_val (struct.t MemKVClerk)) in
    struct.storeF MemKVClerk "coordCk" "ck" "cck";;
    struct.storeF MemKVCoordClerk "cl" (struct.loadF MemKVClerk "coordCk" "ck") (rpc.MakeRPCClient "coord");;
    struct.storeF MemKVClerk "shardClerks" "ck" (MakeShardClerkSet #());;
    struct.storeF MemKVClerk "shardMap" "ck" (MemKVCoordClerk__GetShardMap (struct.loadF MemKVClerk "coordCk" "ck"));;
    "ck".
