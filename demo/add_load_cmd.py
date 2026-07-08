import struct, sys, shutil

path = sys.argv[1]
dylib = "@executable_path/../Frameworks/libpicafix.dylib"

FAT_MAGIC=0xcafebabe; FAT_MAGIC_64=0xcafebabf
MH_MAGIC_64=0xfeedfacf
LC_LOAD_DYLIB=0x0c

def patch_slice(buf, off):
    magic, = struct.unpack_from(">I", buf, off) if False else struct.unpack_from("<I", buf, off)
    assert magic==MH_MAGIC_64, hex(magic)
    ncmds, sizeofcmds = struct.unpack_from("<II", buf, off+16)
    # build new dylib command
    name=dylib.encode()+b"\0"
    namelen=(len(name)+7)&~7
    cmdsize=24+namelen
    cmd=struct.pack("<IIIIII", LC_LOAD_DYLIB, cmdsize, 24, 0, 0x10000, 0x10000)
    cmd+=name+b"\0"*(namelen-len(name))
    # find end of load commands
    lc_start=off+32
    end=lc_start+sizeofcmds
    # ensure zero padding room before first section data
    if buf[end:end+cmdsize]!=b"\0"*cmdsize:
        raise SystemExit(f"no room at slice {off:#x}: bytes not zero")
    buf[end:end+cmdsize]=cmd
    struct.pack_into("<II", buf, off+16, ncmds+1, sizeofcmds+cmdsize)

with open(path,"rb") as f: buf=bytearray(f.read())
magic,=struct.unpack_from(">I", buf, 0)
if magic in (FAT_MAGIC,FAT_MAGIC_64):
    nfat,=struct.unpack_from(">I", buf, 4)
    for i in range(nfat):
        if magic==FAT_MAGIC:
            o=8+i*20; cpu,sub,offset,size,align=struct.unpack_from(">IIIII", buf, o)
        else:
            o=8+i*32; cpu,sub,offset,size,align,_=struct.unpack_from(">IIQQII", buf, o)
        patch_slice(buf, offset)
else:
    patch_slice(buf, 0)
with open(path,"wb") as f: f.write(buf)
print("patched", path)
