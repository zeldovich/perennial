(* autogenerated from github.com/mit-pdos/goose-nfsd/fs *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.disk_prelude.

From Goose Require github_com.mit_pdos.goose_nfsd.buf.
From Goose Require github_com.mit_pdos.goose_nfsd.fake_bcache.bcache.
From Goose Require github_com.mit_pdos.goose_nfsd.util.
From Goose Require github_com.mit_pdos.goose_nfsd.wal.

Definition NBITBLOCK : expr := disk.BlockSize * #8.

Definition INODEBLK : expr := disk.BlockSize `quot` "INODESZ".

Definition NINODEBITMAP : expr := #1.

(* on-disk size *)
Definition INODESZ : expr := #128.

Definition Inum: ty := uint64T.

Definition NULLINUM : expr := #0.

Definition ROOTINUM : expr := #1.

Module FsSuper.
  Definition S := struct.decl [
    "Disk" :: struct.ptrT bcache.Bcache.S;
    "Size" :: uint64T;
    "nLog" :: uint64T;
    "NBlockBitmap" :: uint64T;
    "NInodeBitmap" :: uint64T;
    "nInodeBlk" :: uint64T;
    "Maxaddr" :: uint64T
  ].
End FsSuper.

Definition MkFsSuper: val :=
  λ: "sz" "name",
    let: "nblockbitmap" := "sz" `quot` NBITBLOCK + #1 in
    let: "d" := ref (zero_val Disk) in
    (if: "name" ≠ slice.nil
    then
      util.DPrintf #1 (#(str"MkFsSuper: open file disk %s
      ")) (![stringT] "name");;
      let: ("file", "err") := disk.NewFileDisk (![stringT] "name") "sz" in
      (if: "err" ≠ slice.nil
      then
        Panic ("MkFsSuper: couldn't create disk image");;
        #()
      else #());;
      "d" <-[Disk] "file"
    else
      util.DPrintf #1 (#(str"MkFsSuper: create mem disk
      "));;
      "d" <-[Disk] disk.NewMemDisk "sz");;
    disk.Init (![Disk] "d");;
    let: "bc" := bcache.MkBcache #() in
    struct.new FsSuper.S [
      "Disk" ::= "bc";
      "Size" ::= "sz";
      "nLog" ::= wal.LOGSIZE;
      "NBlockBitmap" ::= "nblockbitmap";
      "NInodeBitmap" ::= NINODEBITMAP;
      "nInodeBlk" ::= NINODEBITMAP * NBITBLOCK * INODESZ `quot` disk.BlockSize;
      "Maxaddr" ::= "sz"
    ].

Definition FsSuper__MaxBnum: val :=
  λ: "fs",
    struct.loadF FsSuper.S "Maxaddr" "fs".

Definition FsSuper__BitmapBlockStart: val :=
  λ: "fs",
    struct.loadF FsSuper.S "nLog" "fs".

Definition FsSuper__BitmapInodeStart: val :=
  λ: "fs",
    FsSuper__BitmapBlockStart "fs" + struct.loadF FsSuper.S "NBlockBitmap" "fs".

Definition FsSuper__InodeStart: val :=
  λ: "fs",
    FsSuper__BitmapInodeStart "fs" + struct.loadF FsSuper.S "NInodeBitmap" "fs".

Definition FsSuper__DataStart: val :=
  λ: "fs",
    FsSuper__InodeStart "fs" + struct.loadF FsSuper.S "nInodeBlk" "fs".

Definition FsSuper__Block2addr: val :=
  λ: "fs" "blkno",
    buf.MkAddr "blkno" #0 NBITBLOCK.

Definition FsSuper__NInode: val :=
  λ: "fs",
    struct.loadF FsSuper.S "nInodeBlk" "fs" * INODEBLK.

Definition FsSuper__Inum2Addr: val :=
  λ: "fs" "inum",
    buf.MkAddr (FsSuper__InodeStart "fs" + "inum" `quot` INODEBLK) ("inum" `rem` INODEBLK * INODESZ * #8) (INODESZ * #8).

Definition FsSuper__DiskBlockSize: val :=
  λ: "fs" "addr",
    (struct.get buf.Addr.S "Sz" "addr" = NBITBLOCK).
