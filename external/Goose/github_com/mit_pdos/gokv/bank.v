(* autogenerated from github.com/mit-pdos/gokv/bank *)
From Perennial.goose_lang Require Import prelude.
From Goose Require github_com.goose_lang.std.
From Goose Require github_com.mit_pdos.gokv.connman.
From Goose Require github_com.mit_pdos.gokv.lockservice.
From Goose Require github_com.mit_pdos.gokv.memkv.

From Perennial.goose_lang Require Import ffi.grove_prelude.

Definition BAL_TOTAL : expr := #1000.

Definition BankClerk := struct.decl [
  "lck" :: ptrT;
  "kvck" :: ptrT;
  "accts" :: slice.T uint64T
].

Definition acquire_two: val :=
  rec: "acquire_two" "lck" "l1" "l2" :=
    (if: "l1" < "l2"
    then
      lockservice.LockClerk__Lock "lck" "l1";;
      lockservice.LockClerk__Lock "lck" "l2"
    else
      lockservice.LockClerk__Lock "lck" "l2";;
      lockservice.LockClerk__Lock "lck" "l1");;
    #().

Definition release_two: val :=
  rec: "release_two" "lck" "l1" "l2" :=
    lockservice.LockClerk__Unlock "lck" "l1";;
    lockservice.LockClerk__Unlock "lck" "l2";;
    #().

(* Requires that the account numbers are smaller than num_accounts
   If account balance in acc_from is at least amount, transfer amount to acc_to *)
Definition BankClerk__transfer_internal: val :=
  rec: "BankClerk__transfer_internal" "bck" "acc_from" "acc_to" "amount" :=
    acquire_two (struct.loadF BankClerk "lck" "bck") "acc_from" "acc_to";;
    let: "old_amount" := memkv.DecodeUint64 (memkv.SeqKVClerk__Get (struct.loadF BankClerk "kvck" "bck") "acc_from") in
    (if: "old_amount" ≥ "amount"
    then
      memkv.SeqKVClerk__Put (struct.loadF BankClerk "kvck" "bck") "acc_from" (memkv.EncodeUint64 ("old_amount" - "amount"));;
      memkv.SeqKVClerk__Put (struct.loadF BankClerk "kvck" "bck") "acc_to" (memkv.EncodeUint64 ((memkv.DecodeUint64 (memkv.SeqKVClerk__Get (struct.loadF BankClerk "kvck" "bck") "acc_to")) + "amount"))
    else #());;
    release_two (struct.loadF BankClerk "lck" "bck") "acc_from" "acc_to";;
    #().

Definition BankClerk__SimpleTransfer: val :=
  rec: "BankClerk__SimpleTransfer" "bck" :=
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      let: "src" := rand.RandomUint64 #() in
      let: "dst" := rand.RandomUint64 #() in
      let: "amount" := rand.RandomUint64 #() in
      (if: (("src" < (slice.len (struct.loadF BankClerk "accts" "bck"))) && ("dst" < (slice.len (struct.loadF BankClerk "accts" "bck")))) && ("src" ≠ "dst")
      then
        BankClerk__transfer_internal "bck" (SliceGet uint64T (struct.loadF BankClerk "accts" "bck") "src") (SliceGet uint64T (struct.loadF BankClerk "accts" "bck") "dst") "amount";;
        Continue
      else Continue));;
    #().

Definition BankClerk__get_total: val :=
  rec: "BankClerk__get_total" "bck" :=
    let: "sum" := ref (zero_val uint64T) in
    ForSlice uint64T <> "acct" (struct.loadF BankClerk "accts" "bck")
      (lockservice.LockClerk__Lock (struct.loadF BankClerk "lck" "bck") "acct";;
      "sum" <-[uint64T] ((![uint64T] "sum") + (memkv.DecodeUint64 (memkv.SeqKVClerk__Get (struct.loadF BankClerk "kvck" "bck") "acct"))));;
    ForSlice uint64T <> "acct" (struct.loadF BankClerk "accts" "bck")
      (lockservice.LockClerk__Unlock (struct.loadF BankClerk "lck" "bck") "acct");;
    ![uint64T] "sum".

Definition BankClerk__SimpleAudit: val :=
  rec: "BankClerk__SimpleAudit" "bck" :=
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      (if: (BankClerk__get_total "bck") ≠ BAL_TOTAL
      then
        Panic "Balance total invariant violated";;
        Continue
      else Continue));;
    #().

Definition MakeBankClerkSlice: val :=
  rec: "MakeBankClerkSlice" "lockhost" "kvhost" "cm" "init_flag" "accts" "cid" :=
    let: "bck" := struct.alloc BankClerk (zero_val (struct.t BankClerk)) in
    struct.storeF BankClerk "lck" "bck" (lockservice.MakeLockClerk "lockhost" "cm");;
    struct.storeF BankClerk "kvck" "bck" (memkv.MakeSeqKVClerk "kvhost" "cm");;
    struct.storeF BankClerk "accts" "bck" "accts";;
    lockservice.LockClerk__Lock (struct.loadF BankClerk "lck" "bck") "init_flag";;
    (if: std.BytesEqual (memkv.SeqKVClerk__Get (struct.loadF BankClerk "kvck" "bck") "init_flag") (NewSlice byteT #0)
    then
      memkv.SeqKVClerk__Put (struct.loadF BankClerk "kvck" "bck") (SliceGet uint64T (struct.loadF BankClerk "accts" "bck") #0) (memkv.EncodeUint64 BAL_TOTAL);;
      ForSlice uint64T <> "acct" (SliceSkip uint64T (struct.loadF BankClerk "accts" "bck") #1)
        (memkv.SeqKVClerk__Put (struct.loadF BankClerk "kvck" "bck") "acct" (memkv.EncodeUint64 #0));;
      memkv.SeqKVClerk__Put (struct.loadF BankClerk "kvck" "bck") "init_flag" (NewSlice byteT #1)
    else #());;
    lockservice.LockClerk__Unlock (struct.loadF BankClerk "lck" "bck") "init_flag";;
    "bck".

Definition MakeBankClerk: val :=
  rec: "MakeBankClerk" "lockhost" "kvhost" "cm" "init_flag" "acc1" "acc2" "cid" :=
    let: "accts" := ref (zero_val (slice.T uint64T)) in
    "accts" <-[slice.T uint64T] (SliceAppend uint64T (![slice.T uint64T] "accts") "acc1");;
    "accts" <-[slice.T uint64T] (SliceAppend uint64T (![slice.T uint64T] "accts") "acc2");;
    MakeBankClerkSlice "lockhost" "kvhost" "cm" "init_flag" (![slice.T uint64T] "accts") "cid".
