(* autogenerated from github.com/mit-pdos/perennial-examples/dir *)
From Perennial.goose_lang Require Import prelude.
From Goose Require github_com.mit_pdos.perennial_examples.alloc.
From Goose Require github_com.mit_pdos.perennial_examples.inode.

From Perennial.goose_lang Require Import ffi.disk_prelude.

Definition NumInodes : expr := #5.

Definition Dir := struct.decl [
  "d" :: disk.Disk;
  "allocator" :: ptrT;
  "inodes" :: slice.T ptrT
].

Definition openInodes: val :=
  rec: "openInodes" "d" :=
    let: "inodes" := ref (zero_val (slice.T ptrT)) in
    let: "addr" := ref_to uint64T #0 in
    (for: (λ: <>, (![uint64T] "addr") < NumInodes); (λ: <>, "addr" <-[uint64T] ((![uint64T] "addr") + #1)) := λ: <>,
      "inodes" <-[slice.T ptrT] (SliceAppend ptrT (![slice.T ptrT] "inodes") (inode.Open "d" (![uint64T] "addr")));;
      Continue);;
    ![slice.T ptrT] "inodes".

Definition inodeUsedBlocks: val :=
  rec: "inodeUsedBlocks" "inodes" :=
    let: "used" := NewMap uint64T (struct.t alloc.unit) #() in
    ForSlice ptrT <> "i" "inodes"
      (alloc.SetAdd "used" (inode.Inode__UsedBlocks "i"));;
    "used".

Definition Open: val :=
  rec: "Open" "d" "sz" :=
    let: "inodes" := openInodes "d" in
    let: "used" := inodeUsedBlocks "inodes" in
    let: "allocator" := alloc.New NumInodes ("sz" - NumInodes) "used" in
    struct.new Dir [
      "d" ::= "d";
      "allocator" ::= "allocator";
      "inodes" ::= "inodes"
    ].

Definition Dir__Read: val :=
  rec: "Dir__Read" "d" "ino" "off" :=
    let: "i" := SliceGet ptrT (struct.loadF Dir "inodes" "d") "ino" in
    inode.Inode__Read "i" "off".

Definition Dir__Size: val :=
  rec: "Dir__Size" "d" "ino" :=
    let: "i" := SliceGet ptrT (struct.loadF Dir "inodes" "d") "ino" in
    inode.Inode__Size "i".

Definition Dir__Append: val :=
  rec: "Dir__Append" "d" "ino" "b" :=
    let: "i" := SliceGet ptrT (struct.loadF Dir "inodes" "d") "ino" in
    inode.Inode__Append "i" "b" (struct.loadF Dir "allocator" "d").
