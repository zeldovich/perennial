(* autogenerated from github.com/mit-pdos/goose-nfsd/kvs *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.disk_prelude.

From Goose Require github_com.mit_pdos.goose_nfsd.addr.
From Goose Require github_com.mit_pdos.goose_nfsd.buftxn.
From Goose Require github_com.mit_pdos.goose_nfsd.common.
From Goose Require github_com.mit_pdos.goose_nfsd.super.
From Goose Require github_com.mit_pdos.goose_nfsd.txn.
From Goose Require github_com.mit_pdos.goose_nfsd.util.

Definition DISKSZ : expr := #10 * #1000.

Definition DISKNAME : expr := #(str"goose_kvs.img").

Module KVS.
  Definition S := struct.decl [
    "txn" :: struct.ptrT txn.Txn.S
  ].
End KVS.

Module KVPair.
  Definition S := struct.decl [
    "Key" :: uint64T;
    "Val" :: slice.T byteT
  ].
End KVPair.

Definition MkKVS: val :=
  rec: "MkKVS" "d" :=
    let: "super" := super.MkFsSuper "d" in
    util.DPrintf #1 (#(str"Super: sz %d %v
    ")) #();;
    let: "txn" := txn.MkTxn "super" in
    let: "kvs" := struct.new KVS.S [
      "txn" ::= "txn"
    ] in
    "kvs".

Definition KVS__MultiPut: val :=
  rec: "KVS__MultiPut" "kvs" "pairs" :=
    let: "btxn" := buftxn.Begin (struct.loadF KVS.S "txn" "kvs") in
    ForSlice (struct.t KVPair.S) <> "p" "pairs"
      (let: "akey" := addr.MkAddr (struct.get KVPair.S "Key" "p" + common.LOGSIZE) #0 in
      buftxn.BufTxn__OverWrite "btxn" "akey" common.NBITBLOCK (struct.get KVPair.S "Val" "p"));;
    let: "ok" := buftxn.BufTxn__CommitWait "btxn" #true in
    "ok".

Definition KVS__Get: val :=
  rec: "KVS__Get" "kvs" "key" :=
    let: "btxn" := buftxn.Begin (struct.loadF KVS.S "txn" "kvs") in
    let: "akey" := addr.MkAddr ("key" + common.LOGSIZE) #0 in
    let: "data" := struct.loadF buf.Buf.S "Data" (buftxn.BufTxn__ReadBuf "btxn" "akey" common.NBITBLOCK) in
    buftxn.BufTxn__CommitWait "btxn" #true;;
    struct.new KVPair.S [
      "Key" ::= "key";
      "Val" ::= "data"
    ].

Definition KVS__Delete: val :=
  rec: "KVS__Delete" "kvs" :=
    txn.Txn__Shutdown (struct.loadF KVS.S "txn" "kvs").
