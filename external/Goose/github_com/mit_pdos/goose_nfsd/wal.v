(* autogenerated from github.com/mit-pdos/goose-nfsd/wal *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.disk_prelude.

From Goose Require github_com.mit_pdos.goose_nfsd.buf.
From Goose Require github_com.mit_pdos.goose_nfsd.fake_bcache.bcache.
From Goose Require github_com.mit_pdos.goose_nfsd.util.
From Goose Require github_com.tchajed.marshal.

(* 0waldefs.go *)

(*  wal implements write-ahead logging

    The layout of log:
    [ installed writes | logged writes | in-memory/logged | unstable in-memory ]
     ^                   ^               ^                  ^
     0                   memStart        diskEnd            nextDiskEnd

    Blocks in the range [diskEnd, nextDiskEnd) are in the process of
    being logged.  Blocks in unstable are unstably committed (i.e.,
    written by NFS Write with the unstable flag and they can be lost
    on crash). Later transactions may absorp them (e.g., a later NFS
    write may update the same inode or indirect block).  The code
    implements a policy of postponing writing unstable blocks to disk
    as long as possible to maximize the chance of absorption (i.e.,
    commitWait or log is full).  It may better to start logging
    earlier. *)

(* space for the end position *)
Definition HDRMETA : expr := #8.

Definition HDRADDRS : expr := disk.BlockSize - HDRMETA `quot` #8.

(* 2 for log header *)
Definition LOGSIZE : expr := HDRADDRS + #2.

Definition LogPosition: ty := uint64T.

Definition LOGHDR : expr := #0.

Definition LOGHDR2 : expr := #1.

Definition LOGSTART : expr := #2.

Module BlockData.
  Definition S := struct.decl [
    "bn" :: buf.Bnum;
    "blk" :: disk.blockT
  ].
End BlockData.

Definition MkBlockData: val :=
  λ: "bn" "blk",
    let: "b" := struct.mk BlockData.S [
      "bn" ::= "bn";
      "blk" ::= "blk"
    ] in
    "b".

Module Walog.
  Definition S := struct.decl [
    "memLock" :: lockRefT;
    "d" :: struct.ptrT bcache.Bcache.S;
    "condLogger" :: condvarRefT;
    "condInstall" :: condvarRefT;
    "memLog" :: slice.T (struct.t BlockData.S);
    "memStart" :: LogPosition;
    "diskEnd" :: LogPosition;
    "nextDiskEnd" :: LogPosition;
    "shutdown" :: boolT;
    "nthread" :: uint64T;
    "condShut" :: condvarRefT;
    "memLogMap" :: mapT LogPosition
  ].
End Walog.

Definition Walog__LogSz: val :=
  λ: "l",
    HDRADDRS.

(* On-disk header in the first block of the log *)
Module hdr.
  Definition S := struct.decl [
    "end" :: LogPosition;
    "addrs" :: slice.T buf.Bnum
  ].
End hdr.

Definition decodeHdr: val :=
  λ: "blk",
    let: "h" := struct.new hdr.S [
      "end" ::= #0;
      "addrs" ::= slice.nil
    ] in
    let: "dec" := marshal.NewDec "blk" in
    struct.storeF hdr.S "end" "h" (marshal.Dec__GetInt "dec");;
    struct.storeF hdr.S "addrs" "h" (marshal.Dec__GetInts "dec" HDRADDRS);;
    "h".

Definition encodeHdr: val :=
  λ: "h",
    let: "enc" := marshal.NewEnc disk.BlockSize in
    marshal.Enc__PutInt "enc" (struct.get hdr.S "end" "h");;
    marshal.Enc__PutInts "enc" (struct.get hdr.S "addrs" "h");;
    marshal.Enc__Finish "enc".

(* On-disk header in the second block of the log *)
Module hdr2.
  Definition S := struct.decl [
    "start" :: LogPosition
  ].
End hdr2.

Definition decodeHdr2: val :=
  λ: "blk",
    let: "h" := struct.new hdr2.S [
      "start" ::= #0
    ] in
    let: "dec" := marshal.NewDec "blk" in
    struct.storeF hdr2.S "start" "h" (marshal.Dec__GetInt "dec");;
    "h".

Definition encodeHdr2: val :=
  λ: "h",
    let: "enc" := marshal.NewEnc disk.BlockSize in
    marshal.Enc__PutInt "enc" (struct.get hdr2.S "start" "h");;
    marshal.Enc__Finish "enc".

Definition Walog__writeHdr: val :=
  λ: "l" "h",
    let: "blk" := encodeHdr (struct.load hdr.S "h") in
    bcache.Bcache__Write (struct.loadF Walog.S "d" "l") LOGHDR "blk".

Definition Walog__readHdr: val :=
  λ: "l",
    let: "blk" := bcache.Bcache__Read (struct.loadF Walog.S "d" "l") LOGHDR in
    let: "h" := decodeHdr "blk" in
    "h".

Definition Walog__writeHdr2: val :=
  λ: "l" "h",
    let: "blk" := encodeHdr2 (struct.load hdr2.S "h") in
    bcache.Bcache__Write (struct.loadF Walog.S "d" "l") LOGHDR2 "blk".

Definition Walog__readHdr2: val :=
  λ: "l",
    let: "blk" := bcache.Bcache__Read (struct.loadF Walog.S "d" "l") LOGHDR2 in
    let: "h" := decodeHdr2 "blk" in
    "h".

(* installer.go *)

Definition Walog__cutMemLog: val :=
  λ: "l" "installEnd",
    let: "i" := ref (struct.loadF Walog.S "memStart" "l") in
    (for: (λ: <>, ![LogPosition] "i" < "installEnd"); (λ: <>, "i" <-[LogPosition] ![LogPosition] "i" + #1) := λ: <>,
      let: "blkno" := struct.get BlockData.S "bn" (SliceGet (struct.t BlockData.S) (struct.loadF Walog.S "memLog" "l") (![LogPosition] "i" - struct.loadF Walog.S "memStart" "l")) in
      let: ("pos", "ok") := MapGet (struct.loadF Walog.S "memLogMap" "l") "blkno" in
      (if: "ok" && ("pos" = ![LogPosition] "i")
      then
        util.DPrintf #5 (#(str"memLogMap: del %d %d
        ")) "blkno" "pos";;
        MapDelete (struct.loadF Walog.S "memLogMap" "l") "blkno"
      else #());;
      Continue);;
    struct.storeF Walog.S "memLog" "l" (SliceSkip (struct.t BlockData.S) (struct.loadF Walog.S "memLog" "l") ("installEnd" - struct.loadF Walog.S "memStart" "l"));;
    struct.storeF Walog.S "memStart" "l" "installEnd".

Definition Walog__installBlocks: val :=
  λ: "l" "bufs",
    let: "n" := slice.len "bufs" in
    let: "i" := ref #0 in
    (for: (λ: <>, ![uint64T] "i" < "n"); (λ: <>, "i" <-[uint64T] ![uint64T] "i" + #1) := λ: <>,
      let: "blkno" := struct.get BlockData.S "bn" (SliceGet (struct.t BlockData.S) "bufs" (![uint64T] "i")) in
      let: "blk" := struct.get BlockData.S "blk" (SliceGet (struct.t BlockData.S) "bufs" (![uint64T] "i")) in
      util.DPrintf #5 (#(str"installBlocks: write log block %d to %d
      ")) (![uint64T] "i") "blkno";;
      bcache.Bcache__Write (struct.loadF Walog.S "d" "l") "blkno" "blk";;
      Continue).

(* Installer holds logLock
   XXX absorp *)
Definition Walog__logInstall: val :=
  λ: "l",
    let: "installEnd" := struct.loadF Walog.S "diskEnd" "l" in
    let: "bufs" := SliceTake (struct.loadF Walog.S "memLog" "l") ("installEnd" - struct.loadF Walog.S "memStart" "l") in
    (if: (slice.len "bufs" = #0)
    then (#0, "installEnd")
    else
      lock.release (struct.loadF Walog.S "memLock" "l");;
      util.DPrintf #5 (#(str"logInstall up to %d
      ")) "installEnd";;
      Walog__installBlocks "l" "bufs";;
      let: "h" := struct.new hdr2.S [
        "start" ::= "installEnd"
      ] in
      Walog__writeHdr2 "l" "h";;
      lock.acquire (struct.loadF Walog.S "memLock" "l");;
      (if: "installEnd" < struct.loadF Walog.S "memStart" "l"
      then
        Panic "logInstall";;
        #()
      else #());;
      Walog__cutMemLog "l" "installEnd";;
      lock.condBroadcast (struct.loadF Walog.S "condInstall" "l");;
      (slice.len "bufs", "installEnd")).

(* installer installs blocks from the on-disk log to their home location. *)
Definition Walog__installer: val :=
  λ: "l",
    lock.acquire (struct.loadF Walog.S "memLock" "l");;
    struct.storeF Walog.S "nthread" "l" (struct.loadF Walog.S "nthread" "l" + #1);;
    Skip;;
    (for: (λ: <>, ~ (struct.loadF Walog.S "shutdown" "l")); (λ: <>, Skip) := λ: <>,
      let: ("blkcount", "txn") := Walog__logInstall "l" in
      (if: "blkcount" > #0
      then
        util.DPrintf #5 (#(str"Installed till txn %d
        ")) "txn"
      else lock.condWait (struct.loadF Walog.S "condInstall" "l"));;
      Continue);;
    util.DPrintf #1 (#(str"installer: shutdown
    "));;
    struct.storeF Walog.S "nthread" "l" (struct.loadF Walog.S "nthread" "l" - #1);;
    lock.condSignal (struct.loadF Walog.S "condShut" "l");;
    lock.release (struct.loadF Walog.S "memLock" "l").

(* logger.go *)

Definition Walog__logBlocks: val :=
  λ: "l" "memend" "memstart" "diskend" "bufs",
    let: "pos" := ref "diskend" in
    (for: (λ: <>, ![LogPosition] "pos" < "memend"); (λ: <>, "pos" <-[LogPosition] ![LogPosition] "pos" + #1) := λ: <>,
      let: "buf" := SliceGet (struct.t BlockData.S) "bufs" (![LogPosition] "pos" - "diskend") in
      let: "blk" := struct.get BlockData.S "blk" "buf" in
      let: "blkno" := struct.get BlockData.S "bn" "buf" in
      util.DPrintf #5 (#(str"logBlocks: %d to log block %d
      ")) "blkno" (![LogPosition] "pos");;
      bcache.Bcache__Write (struct.loadF Walog.S "d" "l") (LOGSTART + ![LogPosition] "pos" `rem` Walog__LogSz "l") "blk";;
      Continue).

(* Logger holds logLock *)
Definition Walog__logAppend: val :=
  λ: "l",
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      (if: slice.len (struct.loadF Walog.S "memLog" "l") ≤ Walog__LogSz "l"
      then Break
      else lock.condWait (struct.loadF Walog.S "condInstall" "l"));;
      Continue);;
    let: "memstart" := struct.loadF Walog.S "memStart" "l" in
    let: "memlog" := struct.loadF Walog.S "memLog" "l" in
    let: "memend" := struct.loadF Walog.S "nextDiskEnd" "l" in
    let: "diskend" := struct.loadF Walog.S "diskEnd" "l" in
    let: "newbufs" := SliceSubslice (struct.t BlockData.S) "memlog" ("diskend" - "memstart") ("memend" - "memstart") in
    (if: (slice.len "newbufs" = #0)
    then #false
    else
      lock.release (struct.loadF Walog.S "memLock" "l");;
      Walog__logBlocks "l" "memend" "memstart" "diskend" "newbufs";;
      let: "addrs" := NewSlice buf.Bnum (Walog__LogSz "l") in
      let: "i" := ref #0 in
      (for: (λ: <>, ![uint64T] "i" < "memend" - "memstart"); (λ: <>, "i" <-[uint64T] ![uint64T] "i" + #1) := λ: <>,
        let: "pos" := "memstart" + ![uint64T] "i" in
        SliceSet uint64T "addrs" ("pos" `rem` Walog__LogSz "l") (struct.get BlockData.S "bn" (SliceGet (struct.t BlockData.S) "memlog" (![uint64T] "i")));;
        Continue);;
      let: "newh" := struct.new hdr.S [
        "end" ::= "memend";
        "addrs" ::= "addrs"
      ] in
      Walog__writeHdr "l" "newh";;
      bcache.Bcache__Barrier (struct.loadF Walog.S "d" "l");;
      lock.acquire (struct.loadF Walog.S "memLock" "l");;
      struct.storeF Walog.S "diskEnd" "l" "memend";;
      lock.condBroadcast (struct.loadF Walog.S "condLogger" "l");;
      lock.condBroadcast (struct.loadF Walog.S "condInstall" "l");;
      #true).

Definition Walog__logger: val :=
  λ: "l",
    lock.acquire (struct.loadF Walog.S "memLock" "l");;
    struct.storeF Walog.S "nthread" "l" (struct.loadF Walog.S "nthread" "l" + #1);;
    Skip;;
    (for: (λ: <>, ~ (struct.loadF Walog.S "shutdown" "l")); (λ: <>, Skip) := λ: <>,
      let: "progress" := Walog__logAppend "l" in
      (if: ~ "progress"
      then lock.condWait (struct.loadF Walog.S "condLogger" "l")
      else #());;
      Continue);;
    util.DPrintf #1 (#(str"logger: shutdown
    "));;
    struct.storeF Walog.S "nthread" "l" (struct.loadF Walog.S "nthread" "l" - #1);;
    lock.condSignal (struct.loadF Walog.S "condShut" "l");;
    lock.release (struct.loadF Walog.S "memLock" "l").

(* wal.go *)

Definition Walog__Recover: val :=
  λ: "l",
    let: "h" := Walog__readHdr "l" in
    let: "h2" := Walog__readHdr2 "l" in
    struct.storeF Walog.S "memStart" "l" (struct.loadF hdr2.S "start" "h2");;
    struct.storeF Walog.S "diskEnd" "l" (struct.loadF hdr.S "end" "h");;
    util.DPrintf #1 (#(str"Recover %d %d
    ")) (struct.loadF Walog.S "memStart" "l") (struct.loadF Walog.S "diskEnd" "l");;
    let: "pos" := ref (struct.loadF hdr2.S "start" "h2") in
    (for: (λ: <>, ![LogPosition] "pos" < struct.loadF hdr.S "end" "h"); (λ: <>, "pos" <-[LogPosition] ![LogPosition] "pos" + #1) := λ: <>,
      let: "addr" := SliceGet uint64T (struct.loadF hdr.S "addrs" "h") (![LogPosition] "pos" `rem` Walog__LogSz "l") in
      util.DPrintf #1 (#(str"recover block %d
      ")) "addr";;
      let: "blk" := bcache.Bcache__Read (struct.loadF Walog.S "d" "l") (LOGSTART + ![LogPosition] "pos" `rem` Walog__LogSz "l") in
      let: "b" := MkBlockData "addr" "blk" in
      struct.storeF Walog.S "memLog" "l" (SliceAppend (struct.t BlockData.S) (struct.loadF Walog.S "memLog" "l") "b");;
      Continue);;
    struct.storeF Walog.S "nextDiskEnd" "l" (struct.loadF Walog.S "memStart" "l" + slice.len (struct.loadF Walog.S "memLog" "l")).

Definition MkLog: val :=
  λ: "disk",
    let: "ml" := lock.new #() in
    let: "l" := struct.new Walog.S [
      "d" ::= "disk";
      "memLock" ::= "ml";
      "condLogger" ::= lock.newCond "ml";
      "condInstall" ::= lock.newCond "ml";
      "memLog" ::= NewSlice (struct.t BlockData.S) #0;
      "memStart" ::= #0;
      "diskEnd" ::= #0;
      "nextDiskEnd" ::= #0;
      "shutdown" ::= #false;
      "nthread" ::= #0;
      "condShut" ::= lock.newCond "ml";
      "memLogMap" ::= NewMap LogPosition
    ] in
    util.DPrintf #1 (#(str"mkLog: size %d
    ")) (Walog__LogSz "l");;
    Walog__Recover "l";;
    Fork (Walog__logger "l");;
    Fork (Walog__installer "l");;
    "l".

(* Assumes caller holds memLock *)
Definition Walog__memWrite: val :=
  λ: "l" "bufs",
    let: "s" := slice.len (struct.loadF Walog.S "memLog" "l") in
    let: "i" := ref #0 in
    ForSlice (struct.t BlockData.S) <> "buf" "bufs"
      (let: "pos" := struct.loadF Walog.S "memStart" "l" + "s" + ![uint64T] "i" in
      let: ("oldpos", "ok") := MapGet (struct.loadF Walog.S "memLogMap" "l") (struct.get BlockData.S "bn" "buf") in
      (if: "ok" && "oldpos" ≥ struct.loadF Walog.S "nextDiskEnd" "l"
      then
        util.DPrintf #5 (#(str"memWrite: absorb %d pos %d old %d
        ")) (struct.get BlockData.S "bn" "buf") "pos" "oldpos";;
        SliceSet (struct.t BlockData.S) (struct.loadF Walog.S "memLog" "l") ("oldpos" - struct.loadF Walog.S "memStart" "l") "buf"
      else
        (if: "ok"
        then
          util.DPrintf #5 (#(str"memLogMap: replace %d pos %d old %d
          ")) (struct.get BlockData.S "bn" "buf") "pos" "oldpos"
        else
          util.DPrintf #5 (#(str"memLogMap: add %d pos %d
          ")) (struct.get BlockData.S "bn" "buf") "pos");;
        struct.storeF Walog.S "memLog" "l" (SliceAppend (struct.t BlockData.S) (struct.loadF Walog.S "memLog" "l") "buf");;
        MapInsert (struct.loadF Walog.S "memLogMap" "l") (struct.get BlockData.S "bn" "buf") "pos";;
        "i" <-[uint64T] ![uint64T] "i" + #1)).

(* Assumes caller holds memLock *)
Definition Walog__doMemAppend: val :=
  λ: "l" "bufs",
    Walog__memWrite "l" "bufs";;
    let: "txn" := struct.loadF Walog.S "memStart" "l" + slice.len (struct.loadF Walog.S "memLog" "l") in
    "txn".

(* Read blkno from memLog, if present *)
Definition Walog__readMemLog: val :=
  λ: "l" "blkno",
    let: "blk" := ref (zero_val (slice.T byteT)) in
    lock.acquire (struct.loadF Walog.S "memLock" "l");;
    let: ("pos", "ok") := MapGet (struct.loadF Walog.S "memLogMap" "l") "blkno" in
    (if: "ok"
    then
      util.DPrintf #5 (#(str"read memLogMap: read %d pos %d
      ")) "blkno" "pos";;
      let: "buf" := SliceGet (struct.t BlockData.S) (struct.loadF Walog.S "memLog" "l") ("pos" - struct.loadF Walog.S "memStart" "l") in
      "blk" <-[slice.T byteT] NewSlice byteT disk.BlockSize;;
      SliceCopy byteT (![slice.T byteT] "blk") (struct.get BlockData.S "blk" "buf");;
      #()
    else #());;
    lock.release (struct.loadF Walog.S "memLock" "l");;
    ![slice.T byteT] "blk".

Definition Walog__Read: val :=
  λ: "l" "blkno",
    let: "blk" := ref (zero_val (slice.T byteT)) in
    let: "blkMem" := Walog__readMemLog "l" "blkno" in
    (if: "blkMem" ≠ slice.nil
    then "blk" <-[slice.T byteT] "blkMem"
    else "blk" <-[slice.T byteT] bcache.Bcache__Read (struct.loadF Walog.S "d" "l") "blkno");;
    ![slice.T byteT] "blk".

(* Append to in-memory log. Returns false, if bufs don't fit.
   Otherwise, returns the txn for this append. *)
Definition Walog__MemAppend: val :=
  λ: "l" "bufs",
    (if: slice.len "bufs" > Walog__LogSz "l"
    then (#0, #false)
    else
      let: "txn" := ref #0 in
      lock.acquire (struct.loadF Walog.S "memLock" "l");;
      Skip;;
      (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
        (if: struct.loadF Walog.S "memStart" "l" + slice.len (struct.loadF Walog.S "memLog" "l") - struct.loadF Walog.S "diskEnd" "l" + slice.len "bufs" > Walog__LogSz "l"
        then
          util.DPrintf #5 (#(str"memAppend: log is full; try again"));;
          struct.storeF Walog.S "nextDiskEnd" "l" (struct.loadF Walog.S "memStart" "l" + slice.len (struct.loadF Walog.S "memLog" "l"));;
          lock.condBroadcast (struct.loadF Walog.S "condLogger" "l");;
          lock.condWait (struct.loadF Walog.S "condLogger" "l");;
          Continue
        else
          "txn" <-[LogPosition] Walog__doMemAppend "l" "bufs";;
          Break));;
      lock.release (struct.loadF Walog.S "memLock" "l");;
      (![LogPosition] "txn", #true)).

(* Wait until logger has appended in-memory log up to txn to on-disk
   log *)
Definition Walog__LogAppendWait: val :=
  λ: "l" "txn",
    util.DPrintf #1 (#(str"LogAppendWait: commit till txn %d
    ")) "txn";;
    lock.acquire (struct.loadF Walog.S "memLock" "l");;
    lock.condBroadcast (struct.loadF Walog.S "condLogger" "l");;
    (if: "txn" > struct.loadF Walog.S "nextDiskEnd" "l"
    then
      struct.storeF Walog.S "nextDiskEnd" "l" "txn";;
      #()
    else #());;
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      (if: "txn" ≤ struct.loadF Walog.S "diskEnd" "l"
      then Break
      else lock.condWait (struct.loadF Walog.S "condLogger" "l"));;
      Continue);;
    lock.release (struct.loadF Walog.S "memLock" "l").

(* Wait until last started transaction has been appended to log.  If
   it is logged, then all preceeding transactions are also logged. *)
Definition Walog__WaitFlushMemLog: val :=
  λ: "l",
    lock.acquire (struct.loadF Walog.S "memLock" "l");;
    let: "n" := struct.loadF Walog.S "memStart" "l" + slice.len (struct.loadF Walog.S "memLog" "l") in
    lock.release (struct.loadF Walog.S "memLock" "l");;
    Walog__LogAppendWait "l" "n".

(* Shutdown logger and installer *)
Definition Walog__Shutdown: val :=
  λ: "l",
    util.DPrintf #1 (#(str"shutdown wal
    "));;
    lock.acquire (struct.loadF Walog.S "memLock" "l");;
    struct.storeF Walog.S "shutdown" "l" #true;;
    lock.condBroadcast (struct.loadF Walog.S "condLogger" "l");;
    lock.condBroadcast (struct.loadF Walog.S "condInstall" "l");;
    Skip;;
    (for: (λ: <>, struct.loadF Walog.S "nthread" "l" > #0); (λ: <>, Skip) := λ: <>,
      util.DPrintf #1 (#(str"wait for logger/installer"));;
      lock.condWait (struct.loadF Walog.S "condShut" "l");;
      Continue);;
    lock.release (struct.loadF Walog.S "memLock" "l");;
    util.DPrintf #1 (#(str"wal done
    ")).
